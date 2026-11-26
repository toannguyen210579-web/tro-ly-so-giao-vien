import 'dart:convert';

import 'package:archive/archive.dart';

import '../data/trinh_chieu.dart';

/// Tạo tệp PowerPoint (.pptx) cho bài trình chiếu: khổ 16:9, chữ to cho máy chiếu, phông Arial (có dấu tiếng Việt),
/// ghi chú giáo viên nằm ở phần Ghi chú của từng trang (xem khi trình chiếu ở chế độ người trình bày).
/// Cấu trúc tệp đã thử bằng python-pptx và LibreOffice (26/11/2026); CI mở thử tệp mẫu (kiem_tra.yml).

const _w = 12192000; // 13,333 in
const _h = 6858000; // 7,5 in
const _head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
const _ns = 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';
const _r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/';
const _clrMap = '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" '
    'accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>';
const _grp = '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/>'
    '<a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>';

String _x(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _theme(String ten) => '$_head<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="${_x(ten)}"><a:themeElements>'
    '<a:clrScheme name="Office"><a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
    '<a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2><a:accent1><a:srgbClr val="4472C4"/></a:accent1>'
    '<a:accent2><a:srgbClr val="ED7D31"/></a:accent2><a:accent3><a:srgbClr val="A5A5A5"/></a:accent3><a:accent4><a:srgbClr val="FFC000"/></a:accent4>'
    '<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5><a:accent6><a:srgbClr val="70AD47"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
    '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme>'
    '<a:fontScheme name="Office"><a:majorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
    '<a:minorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>'
    '<a:fmtScheme name="Office"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>'
    '<a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>'
    '<a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>'
    '<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>'
    '<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>';

String _rels(List<(String, String, String)> ds) =>
    '$_head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${ds.map((e) => '<Relationship Id="${e.$1}" Type="${e.$2}" Target="${e.$3}"/>').join()}</Relationships>';

String _run(String t, int co, String mau, {bool dam = false}) => '<a:r><a:rPr lang="vi-VN" sz="$co"${dam ? ' b="1"' : ''} dirty="0">'
    '<a:solidFill><a:srgbClr val="$mau"/></a:solidFill><a:latin typeface="Arial"/><a:cs typeface="Arial"/></a:rPr><a:t>${_x(t)}</a:t></a:r>';

String _doan(String t, int co, String mau, {bool dam = false, String can = 'l', bool gach = false, int sau = 600}) {
  final ppr = gach
      ? '<a:pPr marL="457200" indent="-457200" algn="$can"><a:lnSpc><a:spcPct val="100000"/></a:lnSpc><a:spcAft><a:spcPts val="$sau"/></a:spcAft>'
          '<a:buClr><a:srgbClr val="$mau"/></a:buClr><a:buFont typeface="Arial"/><a:buChar char="•"/></a:pPr>'
      : '<a:pPr algn="$can"><a:spcAft><a:spcPts val="$sau"/></a:spcAft><a:buNone/></a:pPr>';
  return '<a:p>$ppr${_run(t, co, mau, dam: dam)}</a:p>';
}

String _hop(int id, String ten, int x, int y, int cx, int cy, {String? nen, String doan = '', String neo = 't'}) {
  final fill = nen != null ? '<a:solidFill><a:srgbClr val="$nen"/></a:solidFill>' : '<a:noFill/>';
  final than = doan.isEmpty ? '<a:p><a:endParaRPr lang="vi-VN"/></a:p>' : doan;
  return '<p:sp><p:nvSpPr><p:cNvPr id="$id" name="${_x(ten)}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
      '<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>$fill<a:ln><a:noFill/></a:ln></p:spPr>'
      '<p:txBody><a:bodyPr wrap="square" lIns="91440" tIns="45720" rIns="91440" bIns="45720" anchor="$neo" rtlCol="0"><a:noAutofit/></a:bodyPr>'
      '<a:lstStyle/>$than</p:txBody></p:sp>';
}

String _trang(TrangChieu tr, int so, int tong, String tenBai, MauTrinhChieu m) {
  final chinh = m.hex(m.chinh), dam = m.hex(m.dam), nhat = m.hex(m.nhat);
  const chu = '14233A';
  final sp = StringBuffer();
  if (tr.laBia) {
    sp.write(_hop(2, 'Nền', 0, 0, _w, _h, nen: chinh));
    sp.write(_hop(3, 'Dải dưới', 0, (_h * 0.70).round(), _w, (_h * 0.30).round(), nen: dam));
    sp.write(_hop(4, 'Tên bài', 685800, 1600200, _w - 2 * 685800, 2400000, doan: _doan(tr.tieuDe, 4400, 'FFFFFF', dam: true), neo: 'b'));
    final phu = tr.y.where((s) => s.isNotEmpty).join(' · ');
    if (phu.isNotEmpty) {
      sp.write(_hop(5, 'Môn, lớp', 685800, (_h * 0.70).round() + 300000, _w - 2 * 685800, 1200000, doan: _doan(phu, 2400, 'FFFFFF')));
    }
  } else {
    const dai = 1371600; // dải tiêu đề cao 1,5 in
    sp.write(_hop(2, 'Dải tiêu đề', 0, 0, _w, dai, nen: chinh));
    sp.write(_hop(3, 'Gạch nhấn', 0, dai, _w, 76200, nen: nhat));
    final nhan = tr.hoatDong.trim();
    final tieuDe = (nhan.isEmpty ? '' : _doan(nhan.toUpperCase(), 1400, nhat, dam: true, sau: 0)) + _doan(tr.tieuDe, 3200, 'FFFFFF', dam: true, sau: 0);
    sp.write(_hop(4, 'Tiêu đề', 457200, 0, _w - 914400, dai, doan: tieuDe, neo: 'ctr'));
    final co = coChuNoiDung(tr.y);
    sp.write(_hop(5, 'Nội dung', 457200, dai + 304800, _w - 914400, _h - dai - 304800 - 548640,
        doan: tr.y.map((s) => _doan(s, co, chu, gach: true)).join()));
    sp.write(_hop(6, 'Chân trang', 457200, _h - 457200, _w - 914400, 365760,
        doan: _doan('$tenBai   ·   $so/$tong', 1200, '8A94A6', can: 'r', sau: 0), neo: 'ctr'));
  }
  return '$_head<p:sld $_ns><p:cSld><p:spTree>$_grp$sp</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>';
}

String _ghiChu(String t) {
  final dong = t.trim().isEmpty ? [''] : t.trim().split('\n');
  final doan = dong.map((d) => '<a:p><a:r><a:rPr lang="vi-VN" dirty="0"/><a:t>${_x(d)}</a:t></a:r></a:p>').join();
  return '$_head<p:notes $_ns><p:cSld><p:spTree>$_grp'
      '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Ảnh trang chiếu"/><p:cNvSpPr><a:spLocks noGrp="1" noRot="1" noChangeAspect="1"/></p:cNvSpPr>'
      '<p:nvPr><p:ph type="sldImg"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>'
      '<p:sp><p:nvSpPr><p:cNvPr id="3" name="Ghi chú"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>'
      '<p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/>$doan</p:txBody></p:sp>'
      '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>';
}

const _notesMaster = '$_head<p:notesMaster $_ns><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg><p:spTree>$_grp'
    '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Ảnh trang chiếu"/><p:cNvSpPr><a:spLocks noGrp="1" noRot="1" noChangeAspect="1"/></p:cNvSpPr>'
    '<p:nvPr><p:ph type="sldImg" idx="2"/></p:nvPr></p:nvSpPr>'
    '<p:spPr><a:xfrm><a:off x="381000" y="685800"/><a:ext cx="6096000" cy="3429000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/>'
    '<a:ln w="12700"><a:solidFill><a:prstClr val="black"/></a:solidFill></a:ln></p:spPr></p:sp>'
    '<p:sp><p:nvSpPr><p:cNvPr id="3" name="Ghi chú"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="body" sz="quarter" idx="3"/></p:nvPr></p:nvSpPr>'
    '<p:spPr><a:xfrm><a:off x="685800" y="4343400"/><a:ext cx="5486400" cy="4114800"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
    '<p:txBody><a:bodyPr vert="horz" lIns="91440" tIns="45720" rIns="91440" bIns="45720" rtlCol="0"/><a:lstStyle/>'
    '<a:p><a:pPr lvl="0"/><a:r><a:rPr lang="vi-VN"/><a:t>Ghi chú</a:t></a:r></a:p></p:txBody></p:sp>'
    '</p:spTree></p:cSld>$_clrMap'
    '<p:notesStyle><a:lvl1pPr marL="0" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1400" kern="1200">'
    '<a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl1pPr>'
    '</p:notesStyle></p:notesMaster>';

const _master = '$_head<p:sldMaster $_ns><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg><p:spTree>$_grp</p:spTree></p:cSld>'
    '$_clrMap<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>'
    '<p:txStyles><p:titleStyle><a:lvl1pPr><a:defRPr sz="4400"><a:latin typeface="+mj-lt"/></a:defRPr></a:lvl1pPr></p:titleStyle>'
    '<p:bodyStyle><a:lvl1pPr><a:defRPr sz="2800"><a:latin typeface="+mn-lt"/></a:defRPr></a:lvl1pPr></p:bodyStyle>'
    '<p:otherStyle><a:lvl1pPr><a:defRPr sz="1800"><a:latin typeface="+mn-lt"/></a:defRPr></a:lvl1pPr></p:otherStyle></p:txStyles></p:sldMaster>';

const _layout = '$_head<p:sldLayout $_ns type="blank" preserve="1"><p:cSld name="Trống"><p:spTree>$_grp</p:spTree></p:cSld>'
    '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>';

/// Tạo tệp .pptx từ bài trình chiếu.
List<int> taoPptx(BaiChieu bai, MauTrinhChieu mau) {
  final ds = bai.trang;
  final n = ds.length;
  final types = <(String, String)>[
    ('/ppt/presentation.xml', 'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml'),
    ('/ppt/slideMasters/slideMaster1.xml', 'application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml'),
    ('/ppt/slideLayouts/slideLayout1.xml', 'application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml'),
    ('/ppt/notesMasters/notesMaster1.xml', 'application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml'),
    ('/ppt/theme/theme1.xml', 'application/vnd.openxmlformats-officedocument.theme+xml'),
    ('/ppt/theme/theme2.xml', 'application/vnd.openxmlformats-officedocument.theme+xml'),
    ('/ppt/presProps.xml', 'application/vnd.openxmlformats-officedocument.presentationml.presProps+xml'),
    ('/ppt/viewProps.xml', 'application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml'),
    ('/ppt/tableStyles.xml', 'application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml'),
    ('/docProps/core.xml', 'application/vnd.openxmlformats-package.core-properties+xml'),
    ('/docProps/app.xml', 'application/vnd.openxmlformats-officedocument.extended-properties+xml'),
    for (var i = 1; i <= n; i++) ...[
      ('/ppt/slides/slide$i.xml', 'application/vnd.openxmlformats-officedocument.presentationml.slide+xml'),
      ('/ppt/notesSlides/notesSlide$i.xml', 'application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml'),
    ],
  ];
  final tep = <String, String>{};
  tep['[Content_Types].xml'] = '$_head<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '${types.map((e) => '<Override PartName="${e.$1}" ContentType="${e.$2}"/>').join()}</Types>';
  tep['_rels/.rels'] = _rels([
    ('rId1', '${_r}officeDocument', 'ppt/presentation.xml'),
    ('rId2', 'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties', 'docProps/core.xml'),
    ('rId3', '${_r}extended-properties', 'docProps/app.xml'),
  ]);
  tep['docProps/core.xml'] = '$_head<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>${_x(bai.tieuDe)}</dc:title><dc:creator>Trợ lý số Giáo viên</dc:creator></cp:coreProperties>';
  tep['docProps/app.xml'] = '$_head<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
      '<Application>Trợ lý số Giáo viên</Application><Slides>$n</Slides><Notes>$n</Notes></Properties>';
  tep['ppt/_rels/presentation.xml.rels'] = _rels([
    ('rId1', '${_r}slideMaster', 'slideMasters/slideMaster1.xml'),
    ('rId2', '${_r}notesMaster', 'notesMasters/notesMaster1.xml'),
    ('rId3', '${_r}theme', 'theme/theme1.xml'),
    ('rId4', '${_r}presProps', 'presProps.xml'),
    ('rId5', '${_r}viewProps', 'viewProps.xml'),
    ('rId6', '${_r}tableStyles', 'tableStyles.xml'),
    for (var i = 1; i <= n; i++) ('rId${10 + i}', '${_r}slide', 'slides/slide$i.xml'),
  ]);
  tep['ppt/presentation.xml'] = '$_head<p:presentation $_ns saveSubsetFonts="1">'
      '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
      '<p:notesMasterIdLst><p:notesMasterId r:id="rId2"/></p:notesMasterIdLst>'
      '<p:sldIdLst>${[for (var i = 1; i <= n; i++) '<p:sldId id="${255 + i}" r:id="rId${10 + i}"/>'].join()}</p:sldIdLst>'
      '<p:sldSz cx="$_w" cy="$_h"/><p:notesSz cx="6858000" cy="9144000"/>'
      '<p:defaultTextStyle><a:lvl1pPr marL="0" algn="l" defTabSz="914400"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill>'
      '<a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl1pPr></p:defaultTextStyle></p:presentation>';
  tep['ppt/presProps.xml'] = '$_head<p:presentationPr $_ns/>';
  tep['ppt/viewProps.xml'] = '$_head<p:viewPr $_ns><p:normalViewPr><p:restoredLeft sz="15620"/><p:restoredTop sz="94660"/></p:normalViewPr>'
      '<p:gridSpacing cx="76200" cy="76200"/></p:viewPr>';
  tep['ppt/tableStyles.xml'] =
      '$_head<a:tblStyleLst xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>';
  tep['ppt/theme/theme1.xml'] = _theme('Trợ lý số GV');
  tep['ppt/theme/theme2.xml'] = _theme('Ghi chú');
  tep['ppt/slideMasters/slideMaster1.xml'] = _master;
  tep['ppt/slideMasters/_rels/slideMaster1.xml.rels'] =
      _rels([('rId1', '${_r}slideLayout', '../slideLayouts/slideLayout1.xml'), ('rId2', '${_r}theme', '../theme/theme1.xml')]);
  tep['ppt/slideLayouts/slideLayout1.xml'] = _layout;
  tep['ppt/slideLayouts/_rels/slideLayout1.xml.rels'] = _rels([('rId1', '${_r}slideMaster', '../slideMasters/slideMaster1.xml')]);
  tep['ppt/notesMasters/notesMaster1.xml'] = _notesMaster;
  tep['ppt/notesMasters/_rels/notesMaster1.xml.rels'] = _rels([('rId1', '${_r}theme', '../theme/theme2.xml')]);
  for (var i = 1; i <= n; i++) {
    tep['ppt/slides/slide$i.xml'] = _trang(ds[i - 1], i, n, bai.tieuDe, mau);
    tep['ppt/slides/_rels/slide$i.xml.rels'] = _rels([
      ('rId1', '${_r}slideLayout', '../slideLayouts/slideLayout1.xml'),
      ('rId2', '${_r}notesSlide', '../notesSlides/notesSlide$i.xml'),
    ]);
    tep['ppt/notesSlides/notesSlide$i.xml'] = _ghiChu(ds[i - 1].ghiChu);
    tep['ppt/notesSlides/_rels/notesSlide$i.xml.rels'] = _rels([
      ('rId1', '${_r}notesMaster', '../notesMasters/notesMaster1.xml'),
      ('rId2', '${_r}slide', '../slides/slide$i.xml'),
    ]);
  }
  final a = Archive();
  // [Content_Types].xml đứng đầu tệp nén như PowerPoint vẫn ghi
  for (final ten in ['[Content_Types].xml', ...tep.keys.where((k) => k != '[Content_Types].xml')]) {
    final bytes = utf8.encode(tep[ten]!);
    a.addFile(ArchiveFile(ten, bytes.length, bytes));
  }
  final List<int>? z = ZipEncoder().encode(a);
  return z ?? <int>[];
}
