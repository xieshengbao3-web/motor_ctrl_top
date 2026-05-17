import json
import os
import re
import subprocess
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parent
SRC_DIR = ROOT / "src"
OUT_DOCX = ROOT / "fpga_motor_project_summary.docx"
IMG_DIR = ROOT / "doc_images"
META_JSON = ROOT / "doc_image_meta.json"
PS_SCRIPT = ROOT / "render_module_diagrams.ps1"


ROLE_MAP = {
    "fpga_top": "工程顶层，连接时钟复位、网络收发、电机驱动、编码器测速与采样缓存。",
    "clk_rst_top": "时钟与复位顶层，完成外部时钟接入、RGMII 接收时钟缓冲、PLL 时钟生成与复位分发。",
    "rst_gen": "复位时序发生器，处理外部复位、软复位，并按延时顺序释放各时钟域复位。",
    "rgmii_rx_top": "RGMII 接收总控，完成 MAC/ARP/IP/UDP/ICMP 协议解析并提取控制命令。",
    "rgmii_rx": "RGMII 到 GMII 的接收转换，利用 IDDR 做双沿采样并统计接收异常。",
    "rx_preamble_sfd_parse": "解析以太网前导码和 SFD，判断帧起始是否合法。",
    "rx_eth_header_parse": "解析以太网首部，识别 ARP 与 IPv4 帧类型并提取源 MAC。",
    "rx_arp_parse": "解析 ARP 请求，检测目标 IP 是否命中 FPGA 并产生应答触发。",
    "rx_ip_header_parse": "解析 IPv4 头，识别 UDP/ICMP 请求并提取源 IP、长度、标识等字段。",
    "rx_udp_header_parse": "解析 UDP 首部，检查目标端口并提取对端端口与数据长度。",
    "rx_udp_data_parse": "解析自定义 UDP 负载，生成寄存器读写地址、写数据与读写使能。",
    "rx_icmp_header_parse": "解析 ICMP Echo 请求头，提取标识与序号并产生回包触发。",
    "rx_icmp_data_parse": "缓存 ICMP 数据字段，为 Echo Reply 直接回显提供数据。",
    "rgmii_tx_top": "RGMII 发送总控，组织 ARP/UDP/ICMP 回包并驱动物理发送器。",
    "rgmii_tx": "GMII 到 RGMII 的发送转换，利用 ODDR 输出 DDR 时钟、使能和数据。",
    "tx_frame": "发送组帧状态机，构造 ARP、IP、UDP、ICMP 帧并计算 FCS/校验和。",
    "crc32_d8": "逐字节 CRC32 计算模块，用于以太网帧尾 FCS 生成。",
    "scp0_comm": "寄存器映射模块，承接 UDP 读写请求，提供版本信息、调试量与采样控制。",
    "abz_decoder": "ABZ 编码器与 Hall 状态解析模块，输出机械角、电角和转速。",
    "devider": "定点除法器，被编码器测速逻辑用于速度计算。",
    "sam_data0_buf": "跨时钟域采样缓存，使用双口 RAM 暂存采样数据并触发 UDP 上传。",
    "sixstep_vf_lut": "六步换相与简易 V/f 启动模块，输出 6 路驱动 PWM 门控。",
    "deadtime_comp": "互补死区注入模块，用于功率桥上下管切换保护。",
    "test_data": "测试数据源模块，用于仿真或联调阶段替代真实采样输入。",
}


ORDER = [
    "fpga_top", "clk_rst_top", "rst_gen", "sixstep_vf_lut", "abz_decoder", "devider",
    "sam_data0_buf", "scp0_comm", "rgmii_rx_top", "rgmii_rx", "rx_preamble_sfd_parse",
    "rx_eth_header_parse", "rx_arp_parse", "rx_ip_header_parse", "rx_udp_header_parse",
    "rx_udp_data_parse", "rx_icmp_header_parse", "rx_icmp_data_parse", "rgmii_tx_top",
    "rgmii_tx", "tx_frame", "crc32_d8", "deadtime_comp", "test_data",
]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    return text


def parse_modules():
    module_files = {}
    module_texts = {}
    for path in sorted(SRC_DIR.glob("*.v")):
        text = read_text(path)
        m = re.search(r"\bmodule\s+(\w+)\b", text)
        if not m:
            continue
        name = m.group(1)
        module_files[name] = path
        module_texts[name] = text
    return module_files, module_texts


def parse_port_counts(text: str):
    cleaned = strip_comments(text)
    m = re.search(r"\bmodule\s+\w+\s*\((.*?)\)\s*;", cleaned, flags=re.S)
    if not m:
        return {"input": 0, "output": 0, "inout": 0}
    header = m.group(1)
    return {
        "input": len(re.findall(r"\binput\b", header)),
        "output": len(re.findall(r"\boutput\b", header)),
        "inout": len(re.findall(r"\binout\b", header)),
    }


def parse_instantiations(module_texts):
    module_names = sorted(module_texts.keys(), key=len, reverse=True)
    inst_by_parent = {}
    parents_by_child = {name: [] for name in module_texts}
    for parent, text in module_texts.items():
        cleaned = strip_comments(text)
        hits = []
        for child in module_names:
            if child == parent:
                continue
            pattern = rf"(?ms)\b{re.escape(child)}\b\s*(?:#\s*\(.*?\))?\s+(\w+)\s*\("
            for m in re.finditer(pattern, cleaned):
                inst = m.group(1)
                hits.append((child, inst))
                parents_by_child.setdefault(child, []).append(parent)
        uniq = []
        seen = set()
        for item in hits:
            if item not in seen:
                seen.add(item)
                uniq.append(item)
        inst_by_parent[parent] = uniq
    return inst_by_parent, parents_by_child


def build_summaries(module_files, module_texts, inst_by_parent, parents_by_child):
    summaries = []
    names = ORDER + [n for n in sorted(module_files) if n not in ORDER]
    seen = set()
    for name in names:
        if name in seen or name not in module_files:
            continue
        seen.add(name)
        counts = parse_port_counts(module_texts[name])
        children = [c for c, _ in inst_by_parent.get(name, [])]
        summaries.append({
            "name": name,
            "file_name": module_files[name].name,
            "file_path": str(module_files[name]),
            "role": ROLE_MAP.get(name, "该模块用于本工程中的专用逻辑处理。"),
            "inputs": counts["input"],
            "outputs": counts["output"],
            "inouts": counts["inout"],
            "children": children,
            "parents": parents_by_child.get(name, []),
        })
    return summaries


def build_image_meta(summaries):
    IMG_DIR.mkdir(exist_ok=True)
    items = []
    items.append({
        "kind": "overview",
        "title": "overview",
        "path": str(IMG_DIR / "overview.png"),
    })
    for s in summaries:
        items.append({
            "kind": "module",
            "name": s["name"],
            "title": f"{s['name']} diagram",
            "children": s["children"][:6],
            "parents": s["parents"][:6],
            "path": str(IMG_DIR / f"{s['name']}.png"),
        })
    META_JSON.write_text(json.dumps({"items": items}, ensure_ascii=False, indent=2), encoding="utf-8")


def build_powershell_renderer():
    text = r"""
param(
  [string]$MetaPath
)
Add-Type -AssemblyName System.Drawing

function New-FontObj($name, $size, $style = [System.Drawing.FontStyle]::Regular) {
  return New-Object System.Drawing.Font($name, $size, $style)
}

function Draw-Box($g, $x, $y, $w, $h, $text, $fillColor) {
  $rect = New-Object System.Drawing.RectangleF($x, $y, $w, $h)
  $fill = New-Object System.Drawing.SolidBrush($fillColor)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70,90,120), 2)
  $g.FillRectangle($fill, $rect)
  $g.DrawRectangle($pen, $x, $y, $w, $h)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $font = New-FontObj 'Microsoft YaHei' 12 ([System.Drawing.FontStyle]::Bold)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30,30,30))
  $g.DrawString($text, $font, $brush, $rect, $fmt)
  $brush.Dispose(); $font.Dispose(); $fmt.Dispose(); $pen.Dispose(); $fill.Dispose()
}

function Draw-Arrow($g, $x1, $y1, $x2, $y2) {
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80,95,120), 2)
  $pen.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(5, 5, $true)
  $g.DrawLine($pen, $x1, $y1, $x2, $y2)
  $pen.Dispose()
}

function Add-Title($g, $text, $w) {
  $font = New-FontObj 'Microsoft YaHei' 18 ([System.Drawing.FontStyle]::Bold)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(25,25,25))
  $rect = New-Object System.Drawing.RectangleF(20, 12, ($w-40), 34)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Near
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $g.DrawString($text, $font, $brush, $rect, $fmt)
  $brush.Dispose(); $font.Dispose(); $fmt.Dispose()
}

function New-Canvas($w, $h) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::FromArgb(248,250,252))
  return @($bmp, $g)
}

function Save-Canvas($bmp, $g, $path) {
  $dir = Split-Path -Parent $path
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
}

function Render-Overview($path) {
  $pair = New-Canvas 1800 1100
  $bmp = $pair[0]; $g = $pair[1]
  Add-Title $g 'FPGA Project Module Diagram' 1800
  Draw-Box $g 700 70 360 90 'fpga_top' ([System.Drawing.Color]::FromArgb(215,232,255))

  Draw-Box $g 120 260 280 90 'clk_rst_top' ([System.Drawing.Color]::FromArgb(227,242,253))
  Draw-Box $g 470 260 280 90 'rgmii_rx_top' ([System.Drawing.Color]::FromArgb(227,242,253))
  Draw-Box $g 820 260 280 90 'rgmii_tx_top' ([System.Drawing.Color]::FromArgb(227,242,253))
  Draw-Box $g 1170 260 280 90 'abz_decoder' ([System.Drawing.Color]::FromArgb(227,242,253))
  Draw-Box $g 1520 260 180 90 'sixstep_vf_lut' ([System.Drawing.Color]::FromArgb(227,242,253))

  Draw-Arrow $g 880 160 260 260
  Draw-Arrow $g 880 160 610 260
  Draw-Arrow $g 880 160 960 260
  Draw-Arrow $g 880 160 1310 260
  Draw-Arrow $g 880 160 1610 260

  Draw-Box $g 420 500 280 90 'scp0_comm' ([System.Drawing.Color]::FromArgb(255,243,224))
  Draw-Box $g 1030 500 300 90 'sam_data0_buf' ([System.Drawing.Color]::FromArgb(255,243,224))

  Draw-Arrow $g 610 350 560 500
  Draw-Arrow $g 960 350 1180 500
  Draw-Arrow $g 1310 350 1180 500
  Draw-Arrow $g 560 590 610 350

  $font = New-FontObj 'Microsoft YaHei' 12
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55,55,55))
  $g.DrawString('UDP read/write cmd', $font, $brush, 540, 410)
  $g.DrawString('register reply', $font, $brush, 700, 410)
  $g.DrawString('speed/sample data', $font, $brush, 1210, 410)
  $g.DrawString('buffered sample upload by UDP', $font, $brush, 1040, 620)
  $g.DrawString('6-channel gate drive', $font, $brush, 1535, 370)
  $brush.Dispose(); $font.Dispose()

  Draw-Box $g 190 760 280 80 'RGMII / ARP / IP / UDP / ICMP' ([System.Drawing.Color]::FromArgb(237,247,237))
  Draw-Box $g 560 760 280 80 'ABZ / Hall / speed calc' ([System.Drawing.Color]::FromArgb(237,247,237))
  Draw-Box $g 930 760 280 80 'dual-port RAM / CDC buf' ([System.Drawing.Color]::FromArgb(237,247,237))
  Draw-Box $g 1300 760 280 80 'six-step / PWM gating' ([System.Drawing.Color]::FromArgb(237,247,237))

  Save-Canvas $bmp $g $path
}

function Render-Module($item) {
  $pair = New-Canvas 1400 900
  $bmp = $pair[0]; $g = $pair[1]
  Add-Title $g ($item.name + ' module diagram') 1400

  Draw-Box $g 500 130 400 110 $item.name ([System.Drawing.Color]::FromArgb(215,232,255))

  if ($item.parents.Count -gt 0) {
    Draw-Box $g 80 160 260 80 'parent modules' ([System.Drawing.Color]::FromArgb(255,243,224))
    Draw-Arrow $g 340 200 500 185
    $font = New-FontObj 'Microsoft YaHei' 11
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,45,45))
    $y = 270
    foreach ($p in $item.parents) {
      $g.DrawString($p, $font, $brush, 95, $y)
      $y += 28
    }
    $brush.Dispose(); $font.Dispose()
  }

  if ($item.children.Count -gt 0) {
    $count = $item.children.Count
    $startX = 80
    $gap = [Math]::Floor((1240 - ($count * 180)) / ([Math]::Max(1, ($count - 1))))
    if ($count -eq 1) { $startX = 610; $gap = 0 }
    for ($i = 0; $i -lt $count; $i++) {
      $x = $startX + $i * (180 + $gap)
      Draw-Box $g $x 520 180 80 $item.children[$i] ([System.Drawing.Color]::FromArgb(227,242,253))
      Draw-Arrow $g 700 240 ($x + 90) 520
    }
    $font = New-FontObj 'Microsoft YaHei' 12
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50,50,50))
    $g.DrawString('child modules', $font, $brush, 630, 455)
    $brush.Dispose(); $font.Dispose()
  } else {
    Draw-Box $g 450 520 500 90 'no child modules instantiated' ([System.Drawing.Color]::FromArgb(237,247,237))
    Draw-Arrow $g 700 240 700 520
  }

  Save-Canvas $bmp $g $item.path
}

$meta = Get-Content $MetaPath -Raw | ConvertFrom-Json
foreach ($item in $meta.items) {
  if ($item.kind -eq 'overview') { Render-Overview $item.path }
  else { Render-Module $item }
}
"""
    PS_SCRIPT.write_text(text, encoding="utf-8")


def run_powershell_renderer():
    subprocess.run(
        ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(PS_SCRIPT), "-MetaPath", str(META_JSON)],
        cwd=str(ROOT),
        check=True,
    )


def image_paragraph(rid, width_px, height_px, name):
    cx = int(width_px * 9525)
    cy = int(height_px * 9525)
    return (
        "<w:p><w:r><w:drawing>"
        "<wp:inline distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\" "
        "xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\">"
        f"<wp:extent cx=\"{cx}\" cy=\"{cy}\"/>"
        "<wp:docPr id=\"1\" name=\"Picture\"/>"
        "<a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">"
        "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
        "<pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
        "<pic:nvPicPr>"
        f"<pic:cNvPr id=\"0\" name=\"{escape(name)}\"/>"
        "<pic:cNvPicPr/>"
        "</pic:nvPicPr>"
        "<pic:blipFill>"
        f"<a:blip r:embed=\"{rid}\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"/>"
        "<a:stretch><a:fillRect/></a:stretch>"
        "</pic:blipFill>"
        "<pic:spPr>"
        "<a:xfrm><a:off x=\"0\" y=\"0\"/>"
        f"<a:ext cx=\"{cx}\" cy=\"{cy}\"/></a:xfrm>"
        "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>"
        "</pic:spPr>"
        "</pic:pic>"
        "</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>"
    )


def p(text, style=None, bold=False):
    style_xml = f'<w:pPr><w:pStyle w:val="{style}"/></w:pPr>' if style else ""
    run_prop = "<w:rPr><w:b/></w:rPr>" if bold else ""
    return f"<w:p>{style_xml}<w:r>{run_prop}<w:t xml:space=\"preserve\">{escape(text)}</w:t></w:r></w:p>"


def bullet(text):
    return p(f"- {text}")


def styles_xml():
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="宋体"/>
      <w:sz w:val="22"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:after="240"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="36"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="30"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="180" w:after="80"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="26"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="120" w:after="40"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="24"/></w:rPr>
  </w:style>
</w:styles>
"""


def content_types_xml(image_count):
    overrides = [
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>',
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>',
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
    ]
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Default Extension="png" ContentType="image/png"/>'
        + "".join(overrides) +
        "</Types>"
    )


def rels_xml():
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"""


def core_xml():
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcmitype="http://purl.org/dc/dcmitype/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>FPGA 电机控制与以太网通信工程说明</dc:title>
  <dc:creator>Codex</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">2026-05-05T00:00:00Z</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">2026-05-05T00:00:00Z</dcterms:modified>
</cp:coreProperties>
"""


def app_xml():
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
 xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Codex</Application>
</Properties>
"""


def build_docx(summaries):
    rels = []
    image_map = {}
    next_rid = 2
    for img in sorted(IMG_DIR.glob("*.png")):
        rid = f"rId{next_rid}"
        next_rid += 1
        rels.append(
            f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/{img.name}"/>'
        )
        image_map[img.stem] = rid

    body = []
    body.append(p("FPGA 电机控制与以太网通信工程说明", style="Title"))
    body.append(p("自动生成文档，基于 src 目录下 Verilog 文件的模块解析结果以及图片化模块图。"))
    body.append(p("1. 工程总览", style="Heading1"))
    body.append(p("本工程以 fpga_top 为顶层，集成了时钟复位、RGMII 以太网收发、UDP/ICMP/ARP 协议解析、编码器测速、六步换相输出以及采样缓存上传功能。"))
    body.append(p("工程总模块连接图", style="Heading2"))
    body.append(image_paragraph(image_map["overview"], 1200, 733, "overview"))
    body.append(bullet("控制链路：PC 通过 UDP 写寄存器，scp0_comm 输出控制信号，如软复位和采样启动。"))
    body.append(bullet("读回链路：PC 通过 UDP 读寄存器，tx_frame 组织 UDP 返回帧。"))
    body.append(bullet("采样链路：abz_decoder 输出速度数据，经 sam_data0_buf 缓存后由 rgmii_tx_top 发出。"))
    body.append(bullet("网络维护链路：工程支持 ARP 应答与 ICMP Echo Reply。"))
    body.append(p("2. 模块章节", style="Heading1"))

    for s in summaries:
        body.append(p(s["name"], style="Heading2"))
        body.append(p(s["role"]))
        body.append(bullet(f"文件：src/{s['file_name']}"))
        body.append(bullet(f"端口数量：input={s['inputs']}，output={s['outputs']}，inout={s['inouts']}"))
        body.append(bullet(f"上层关系：{'、'.join(s['parents']) if s['parents'] else '无上层实例化记录'}"))
        body.append(bullet(f"下层关系：{'、'.join(s['children']) if s['children'] else '无子模块实例化'}"))
        body.append(p("模块图", style="Heading3"))
        body.append(image_paragraph(image_map[s["name"]], 980, 630, s["name"]))
        if s["name"] == "fpga_top":
            body.append(bullet("顶层直接挂接外部时钟、复位、RGMII PHY、编码器 ABZ/Hall、驱动桥臂以及测试 IO。"))
            body.append(bullet("内部将网络控制链路与电机数据链路连接在一起，是整个工程的系统集成点。"))
        elif s["name"] == "abz_decoder":
            body.append(bullet("通过 A/B 相边沿判断转动方向和角度增量，并通过 Z 相进行角度校正。"))
            body.append(bullet("输出机械角、电角和速度，其中速度经过定点除法器计算。"))
        elif s["name"] == "sam_data0_buf":
            body.append(bullet("使用双口 RAM 在 50 MHz 采样域写入，在 125 MHz RGMII 域读出。"))
            body.append(bullet("采样满半缓冲或整缓冲时触发 UDP 上传。"))
        elif s["name"] == "scp0_comm":
            body.append(bullet("当前寄存器映射包含版本信息、复位控制、RGMII/PLL 调试量及采样启动位。"))
            body.append(bullet("是上位机 UDP 控制命令与内部控制信号之间的桥梁。"))
        elif s["name"] == "tx_frame":
            body.append(bullet("内部是发送状态机，覆盖 PREAMBLE、ETH、ARP、IP、UDP、ICMP、FCS、IFG 等阶段。"))
            body.append(bullet("支持寄存器读回包、采样数据上传包、ARP Reply 和 ICMP Reply。"))
        elif s["name"] == "sixstep_vf_lut":
            body.append(bullet("采用六步换相表驱动三相桥，频率随时间缓升。"))
            body.append(bullet("同时叠加固定 PWM 门控，实现简易 V/f 和占空限制。"))
        elif s["name"] in ("deadtime_comp", "test_data"):
            body.append(bullet("该模块存在于工程中，但当前顶层未接入主路径。"))
        else:
            body.append(bullet("该模块在其所属功能链路中承担专用解析、转换或控制任务。"))

    sect = (
        "<w:sectPr>"
        "<w:pgSz w:w=\"11906\" w:h=\"16838\"/>"
        "<w:pgMar w:top=\"1440\" w:right=\"1080\" w:bottom=\"1440\" w:left=\"1080\" "
        "w:header=\"708\" w:footer=\"708\" w:gutter=\"0\"/>"
        "</w:sectPr>"
    )

    document_xml = (
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        "<w:document xmlns:wpc=\"http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas\" "
        "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" "
        "xmlns:o=\"urn:schemas-microsoft-com:office:office\" "
        "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
        "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\" "
        "xmlns:v=\"urn:schemas-microsoft-com:vml\" "
        "xmlns:wp14=\"http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing\" "
        "xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" "
        "xmlns:w10=\"urn:schemas-microsoft-com:office:word\" "
        "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
        "xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\" "
        "xmlns:wpg=\"http://schemas.microsoft.com/office/word/2010/wordprocessingGroup\" "
        "xmlns:wpi=\"http://schemas.microsoft.com/office/word/2010/wordprocessingInk\" "
        "xmlns:wne=\"http://schemas.microsoft.com/office/2006/wordml\" "
        "xmlns:wps=\"http://schemas.microsoft.com/office/word/2010/wordprocessingShape\" "
        "mc:Ignorable=\"w14 wp14\">"
        f"<w:body>{''.join(body)}{sect}</w:body></w:document>"
    )

    document_rels = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        + "".join(rels) +
        "</Relationships>"
    )

    with zipfile.ZipFile(OUT_DOCX, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types_xml(len(rels)))
        zf.writestr("_rels/.rels", rels_xml())
        zf.writestr("word/document.xml", document_xml)
        zf.writestr("word/styles.xml", styles_xml())
        zf.writestr("word/_rels/document.xml.rels", document_rels)
        zf.writestr("docProps/core.xml", core_xml())
        zf.writestr("docProps/app.xml", app_xml())
        for img in sorted(IMG_DIR.glob("*.png")):
            zf.write(img, f"word/media/{img.name}")


def main():
    module_files, module_texts = parse_modules()
    inst_by_parent, parents_by_child = parse_instantiations(module_texts)
    summaries = build_summaries(module_files, module_texts, inst_by_parent, parents_by_child)
    build_image_meta(summaries)
    build_powershell_renderer()
    run_powershell_renderer()
    build_docx(summaries)
    print(str(OUT_DOCX))


if __name__ == "__main__":
    main()
