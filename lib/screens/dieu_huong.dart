import 'package:flutter/material.dart';

import '../data/tien_ich.dart';
import 'anh_sang_word.dart';
import 'anh_the.dart';
import 'cham_trac_nghiem.dart';
import 'cong_cu_tren_lop.dart';
import 'doc_to_ghi_loi.dart';
import 'giai_de.dart';
import 'gio_the.dart';
import 'hop_bien_ban.dart';
import 'lich_nhac_han.dart';
import 'o_chu.dart';
import 'hoi_tro_ly.dart';
import 'nhan_phu_huynh.dart';
import 'nhan_xet.dart';
import 'quet_pdf.dart';
import 'sap_co.dart';
import 'so_minh_chung.dart';
import 'tinh_luong.dart';
import 'xem_them.dart';

/// Mở một tiện ích. Tiện ích nào đã làm xong thì thêm vào đây.
void moTienIch(BuildContext context, TienIch t) {
  final Widget man;
  switch (t.ma) {
    case 'nhan_xet':
      man = const NhanXetHocSinh();
    case 'nhan_ph':
      man = const NhanPhuHuynh();
    case 'quet':
      man = const QuetPdf();
    case 'anh_the':
      man = const AnhThe();
    case 'hop':
      man = const HopBienBan();
    case 'minh_chung':
      man = const SoMinhChung();
    case 'cham_tn':
      man = const ChamTracNghiem();
    case 'luong':
      man = const TinhLuong();
    case 'cong_cu':
      man = const CongCuTrenLop();
    case 'lich':
      man = const LichNhacHan();
    case 'o_chu':
      man = const OChuMan();
    case 'tao_de':
      man = const GiaiDe();
    case 'doc_to':
      man = const DocToGhiLoi();
    case 'sang_word':
      man = const AnhSangWord();
    case 'gio_the':
      man = const GioThe();
    default:
      man = SapCo(tienIch: t);
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
}

void moXemThem(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const XemThem()));
}

void moHoiTroLy(BuildContext context, {String? cauHoi}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => HoiTroLy(cauHoiDau: cauHoi)),
  );
}

/// Xử lý câu gõ ở ô "Thầy cô cần làm gì?": khớp tiện ích thì mở tiện ích,
/// không khớp thì chuyển sang Hỏi Trợ lý.
void xuLyCauNhap(BuildContext context, String cau) {
  final c = cau.trim();
  if (c.isEmpty) {
    moHoiTroLy(context);
    return;
  }
  final t = timTheoCau(c);
  if (t != null) {
    moTienIch(context, t);
  } else {
    moHoiTroLy(context, cauHoi: c);
  }
}
