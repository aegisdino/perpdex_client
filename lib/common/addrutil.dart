import 'package:flutter/foundation.dart';

import 'util.dart';

String eowRegex1 = r"((?=(\(|\,))|\s|$)";
String eowRegex2 = r"(?=(\s|$|[^\w]))";

enum AddressType { Jibun, Doro, Block }

class AddressInfo {
  AddressType addrtype;
  String? sigungu;
  String? bunji;
  String? bdname;
  String? dongho;
  String? aux;
  String address;
  String fulladdress;

  AddressInfo({
    required this.addrtype,
    this.sigungu,
    this.bunji,
    required this.address,
    this.bdname,
    this.dongho,
    this.aux,
    required this.fulladdress,
  });

  String get shortAddress {
    if (sigungu.isNotNullEmptyOrWhitespace) {
      sigungu = sigungu!
          .replaceAll('특별시', '')
          .replaceAll('광역시', '')
          .replaceAll('특별자치', '');
      List<String> parts = [sigungu!, bunji ?? ''];
      if (dongho.isNotNullEmptyOrWhitespace) {
        if (bdname.isNotNullEmptyOrWhitespace) parts.add(bdname!);
        parts.add(dongho!);
      }
      return parts.join(' ');
    }
    return address;
  }
}

class AddrUtil {
  // regex 넣어서 검증할 수 있는 사이트
  // https://regex101.com/

  // 도로명 주소에서 도로명 얻어내는 regex
  static final RegExp doroAddrRegex = RegExp(
      r'([가-힣A-Z·\d~\-\.]{1,})(로\s*((\d{1,4}\-\d{1,4}|\d{1,4})(길(\s*\d{1,4}(\-\d{1,4})?)?)?)|\d{0,4}길(\s*\d{1,4}(\-\d{1,4})?)?)(?=(\s|\,|\)|\(|$))');

  // 번지 주소에서 번지를 얻어내는 regex
  static final RegExp bunjiRegex = RegExp(
      r"(?<=(\s|동|면|리|가))(산\s*)?(\d{1,4}\-\d{1,4}|\d{1,4})(\s*번지)?((\s*외)\s*\d{1,3}\s*(필지))?((?=(\(|\,))|\s|$)");

  // 블록/로트번호로 되어 있는 번지 찾아내는 regex
  static final RegExp blockBunjiRegex = RegExp(
      r"((?<=\s)|^)(([\(\)가-힣A-Z0-9\-]+(구역|로트|롯트|블록|블럭|용지))|BL|가\-)\s*(\d*(\-)?\d{0,3})*((?=(\(|\,))|\s|$)");

  // 가지번은 별도로 처리 (가-.... 형태)
  static final RegExp gaBunjiRegex = RegExp(r"(가\-)(\d{0,4}(\-\d{0,4})?)");

  // 제 4    동   제   2     층   제 602   호
  // 123-133
  //
  // 제...동/제...층/제...호 의 규칙이 너무 다양하여 아주 일반적인 것을 받아들이도록 수정
  static final RegExp dongHoRegex = RegExp(
      r"(((?<=(\s|\,|\(|\[))|^)((((제\s*)?\(?(\d{1,4}(\,\d{1,4})*|에이|에프|에이치|아이|제이|케이|에스|상가|[A-Za-z가-힣])\s*호?동\)?)|(제[A-Za-z가-힣\d]+동)|(\s*(제\s*)?(.[A-Z]|[a-z]|[가-힣]|\d|\-|\(|\)|\,)+층)|(\s*제?(.[A-Z]|[a-z]|[가-힣]|\d|\-|\(|\)|\,)+호))(\,|\.)?)+|((?<!(동|읍|면|리|가|길|로))(\s+\d{1,4}\-\d{1,4})))((?=(\(|\,|\)|\]|\s))|$)");

  static final RegExp sidoRegex = RegExp(
      r"((서울|인천|광주|대구|울산|부산|대전|세종)(시|특별시|광역시|특별자치시)?)|((경기|강원|충청|전라|경상|제주)(도|남도|북도|특별자치도)?)|(전남|전북|경남|경북|충남|충북)");

  // (천호동, 강변그대家(가) River View(리버 뷰))
  static final RegExp auxInfoRegex = RegExp(
      r"\(([가-힣0-9]+(동|가)\,)?\s*(([가-힣0-9A-Za-z\s\-一-龥]{2,}|\([가-힣A-Za-z\s0-9一-龥]+\))+)\)");

  // [집합건물], (건물) 등을 스킵하기 위함
  static final RegExp startingBracket =
      RegExp(r"^(\(([가-힣A-Z0-9\s]+)\)|\[([가-힣A-Z0-9\s]+)\])");

  // [가산동 236-8]과 같은 형태로 들어가 있는 것 체크 위함
  static final RegExp allBracket = RegExp(r"\[([가-힣A-Z0-9\-\s]+)\]");

  // iros의 동/층/호 분리를 위한
  static final RegExp irosDongRegex = RegExp(
      r"((제\s*)?\(?(\d{1,4}(\,\d{1,4})*|에이|에프|에이치|아이|제이|케이|에스|상가|[A-Za-z가-힣])\s*호?동\)?)|(제[A-Za-z가-힣\d]+동)");
  static final RegExp irosFloorRegex = RegExp(r"(제\s*)?((지하|지|상가|B)?\d*층)");
  static final RegExp irosHoRegex =
      RegExp(r"(제\s*)?((.[A-Z]|[a-z]|[가-힣]|\d|\-|\(|\)|\,)+호)");

  // 주소에 a동, b동 같은 걸 한글로 바꿔야 등기소에서 검색이 됨
  static Map<String, String> engHan = {
    'a': "에이",
    'b': "비",
    'c': "씨",
    'd': "디",
    'e': "이",
    'f': "에프",
    'g': "지",
    'h': "에이치",
    'i': "아이",
    'j': "제이",
    'k': "케이",
    'l': "엘",
    'm': "엠",
    'n': "엔",
    'o': "오",
    'p': "피",
    'q': "큐",
    'r': "알",
    's': "에스",
    't': "티",
    'u': "유",
    'v': "브이",
    'w': "더블유",
    'x': "엑스",
    'y': "와이",
    'z': "제트"
  };

  static Map<String, String> hanEng = {
    "에이": "A",
    "비": "B",
    "씨": "C",
    "디": "D",
    "이": "E",
    "에프": "F",
    "지": "G",
    "에이치": "H",
    "아이": "I",
    "제이": "J",
    "케이": "K",
    "엘": "L",
    "엠": "M",
    "엔": "N",
    "오": "O",
    "피": "P",
    "큐": "Q",
    "알": "R",
    "에스": "S",
    "티": "T",
    "유": "U",
    "브이": "V",
    "더블유": "W",
    "엑스": "X",
    "와이": "Y",
    "제트": "Z",
  };

  static Set<String> _addressSearchKeySet = new Set<String>();
  static List<String> addressSearchKey = [];
  static List<String> addressSearchSplitKeyList = [];
  static List<String> addressSearchChosungKeyList = [];

  // 법정동 행정구역 코드 로딩
  static Future init() async {}

  static bool isBunji(String bunji) {
    return bunjiRegex.firstMatch(bunji) != null;
  }

  static bool isDoroAddress(String address) {
    if (address.isNotNullEmptyOrWhitespace) {
      var result = doroAddrRegex.firstMatch(address);
      if (result != null) {
        final doroname = result.group(0)!.trim();
        if (doroname.startsWith("세종로") ||
            doroname.startsWith("시장북로") ||
            doroname.startsWith("남성로")) return false;

        // 빌딩이름이 도로명으로 잡히는 경우가 있어서,
        // (인천광역시 남동구 논현동 755-4 에코메트로12)
        // 도로명 앞의 주소에 번지가 있는지 확인
        String sidogu = address.substring(0, result.start);
        final bunjiMatch = bunjiRegex.firstMatch(sidogu);
        return (bunjiMatch == null);
      }
    }
    return false;
  }

  static List<String> _splitAddresses(String address) {
    var elms = address
        .split(RegExp(r"(,|\s+)"))
        .where((v) => v != '' && v != ',')
        .toList();
    for (var i = 0; i < elms.length; i++) {
      if (elms[i].endsWith('시') || elms[i].endsWith('도')) {
        return elms.sublist(i);
      }
    }
    return elms;
  }

  static String getSidoAddress(String text) {
    final sidoMatch = sidoRegex.firstMatch(text);
    if (sidoMatch != null) {
      return text.substring(sidoMatch.start);
    }
    return text;
  }

  static AddressInfo? _splitDoroAddress(String address) {
    String? doroNum, bdname, dongho, auxInfo;
    var doroMatch = doroAddrRegex.firstMatch(address);
    if (doroMatch != null) {
      doroNum = doroMatch.group(0);

      String sidogu = address.substring(0, doroMatch.start);
      final sidoMatch = sidoRegex.firstMatch(sidogu);
      if (sidoMatch != null) {
        sidogu = sidogu.substring(sidoMatch.start);
      }

      String addrPart2 = address.substring(doroMatch.end);
      if (addrPart2.isNotNullEmptyOrWhitespace) {
        List<String> result = splitAddrPart2(addrPart2);
        dongho = result[0];
        bdname = result[1];
        auxInfo = result[2];
      }
      String _doroAddress = [sidogu.trim(), doroNum].join(' ');
      return AddressInfo(
        addrtype: AddressType.Doro,
        sigungu: sidogu.trim(),
        bunji: doroNum,
        address: _doroAddress,
        bdname: bdname ?? '',
        dongho: dongho ?? '',
        aux: auxInfo ?? '',
        fulladdress: address,
      );
    } else {
      debugPrint("splitDoroAddress: '$address' no doro found");
      return null;
    }
  }

  // 지번 주소 규칙상의 번지 위치
  static int jibunAddressBunjiIndex(List<String> jibunaddrs,
      {int startIndex = 0}) {
    int guIndex = -1;
    for (var i = startIndex; i < jibunaddrs.length; i++) {
      if (guIndex != -1) {
        if (jibunaddrs[i].endsWith('동') ||
            jibunaddrs[i].endsWith('가') ||
            jibunaddrs[i].endsWith('리')) {
          // 광역/기초/시군구/동리
          // 경기도 수원시 장안구 정자동 687
          // 경기도 수원시 팔달구 매산로3가 45-10
          return i + 1;
        } else if (jibunaddrs[i].endsWith('읍') || jibunaddrs[i].endsWith('면')) {
          // 광역/기초/시군구/읍면/동리
          // 경남 창원시 의창구 대산면 가술리 323-4
          return i + 2;
        }
      } else if (jibunaddrs[i].endsWith('구') || jibunaddrs[i].endsWith('군')) {
        // 구군이 나옴
        // 다음에 동리 또는 읍면/동리 2가지
        guIndex = i;
      } else if (jibunaddrs[i].endsWith('읍') || jibunaddrs[i].endsWith('면')) {
        // 구군없이 시다음에 오는 읍면/동리
        // 세종시 조치원읍 신흥리 24-3
        // 제주도 서귀포시 성산읍 성산리 160
        return i + 2;
      }
    }

    return jibunaddrs.length;
  }

  // 서울특별시 관악구 봉천동 635-482번지 한국주택 4층401호 (탄현동,일산두산위브더제니스)
  // addrPart2 = 한국주택 4층401호 (탄현동,일산두산위브더제니스)
  static List<String> splitAddrPart2(String addrPart2) {
    String? dongho, auxInfo, bdname;

    // # ,@#$%&와 공백으로 시작되는 글자들을 모두 삭제
    addrPart2 =
        addrPart2.replaceAllMapped(RegExp(r'^(\,|@|#|\$|%|&)*\s*'), (match) {
      return '';
    }).trimRight();

    // 마지막이 괄호로 끝나는 경우 매칭되는 시작 괄호를 찾아서 없애줌
    if (addrPart2.endsWith(')')) {
      int parenDepth = 1;
      for (var i = addrPart2.length - 2; i > 0; i--) {
        if (addrPart2[i] == '(') {
          parenDepth--;
          if (parenDepth == 0) {
            auxInfo = addrPart2.substring(i);
            addrPart2 = addrPart2.substring(0, i);
            break;
          }
        } else if (addrPart2[i] == ')') {
          parenDepth++;
        }
      }
    }

    RegExpMatch? donghoMatch = dongHoRegex.firstMatch(addrPart2);
    if (donghoMatch != null) {
      dongho = donghoMatch.group(0)!.trim();

      if (auxInfo == null) {
        auxInfo = addrPart2.substring(donghoMatch.end);
        if (auxInfo.isNotNullEmptyOrWhitespace) {
          var match = auxInfoRegex.firstMatch(auxInfo);
          if (match != null) {
            bdname = match[3]!.trim();
          } else {
            debugPrint("splitAddrPart2: 빌딩이름 찾기 regex 실패, auxInfo $auxInfo");
          }
        }
      }

      if (bdname == null)
        bdname = addrPart2.substring(0, donghoMatch.start).trim();

      // 간혹 빌딩이름에 동호가 들어가는 경우가 있어서 이 경우 핸들링
      if (bdname.startsWith('제') && bdname.startsWith('호')) {
        donghoMatch = dongHoRegex.firstMatch(bdname);
        if (donghoMatch != null) {
          dongho = donghoMatch.group(0)!.trim();
          bdname = '';
        }
      }

      //debugPrint("동호 '$dongho', 빌딩 '$bdname', 부가정보 '$auxInfo'");
      return [dongho, bdname, auxInfo];
    } else {
      var match = auxInfoRegex.firstMatch(addrPart2);
      if (match != null) {
        bdname = match[3]!.trim();
        debugPrint("동호없음, 빌딩이름으로 사용: '$bdname'");
      } else {
        debugPrint("splitAddrPart2: 빌딩이름 찾기 regex 실패, addrPart2 $addrPart2");
      }
      return ['', bdname ?? '', ''];
    }
  }

  static AddressInfo? _splitJibunAddress(String address) {
    if (address.isNullEmptyOrWhitespace) return null;

    String? sigungudong, bunji, dongho, bdname, auxInfo;
    int auxInfoStart;
    final bunjiMatch = bunjiRegex.firstMatch(address);
    if (bunjiMatch != null) {
      bunji = bunjiMatch.group(0)?.trim();
      sigungudong =
          getSidoAddress(address.substring(0, bunjiMatch.start).trim());

      String addrPart2 = address.substring(bunjiMatch.end);
      if (addrPart2.isNotNullEmptyOrWhitespace) {
        List<String> result = splitAddrPart2(addrPart2);
        dongho = result[0];
        bdname = result[1];
        auxInfo = result[2];
      }

      //debugPrint('동호 $dongho, 빌딩 $bdname, 추가정보 $auxInfo');
    } else {
      // 번지를 regex로 못찾을 경우 대안으로 처리
      debugPrint("splitJibunAddress: '$address' no bunji found");

      var elms = _splitAddresses(address);
      int bunjiPos = jibunAddressBunjiIndex(elms);
      sigungudong = getSidoAddress(elms.sublist(0, bunjiPos).join(' '));
      if (bunjiPos < elms.length) {
        // 다음 4가지 경우 만족하는 정규식
        // 1234-1334
        // 1134
        // 산1234-1334
        // 산1134
        final bunjiMatch = bunjiRegex.firstMatch(elms[bunjiPos]);
        if (bunjiMatch != null)
          bunji = bunjiMatch.group(0);
        else {
          bunji = elms[bunjiPos].trim();
          debugPrint(
              'splitJibunAddress: bunjiPos $bunjiPos, 잘못된 번지 ${elms[bunjiPos]}');
        }
      }
      auxInfoStart = bunjiPos + 1;

      List<String> bdnames = [], donghos = [], auxInfos = [];
      for (var i = auxInfoStart; i < elms.length; i++) {
        if (elms[i].contains('외') || elms[i].contains('필지') || elms[i] == '번지')
          continue;
        if (elms[i].endsWith('동') ||
            elms[i].endsWith('층') ||
            elms[i].endsWith('호')) {
          for (var j = i; j < elms.length; j++) {
            if (elms[j].startsWith('(')) {
              auxInfos = elms.sublist(j);
              break;
            }
            donghos.add(elms[j]);
          }
          break;
        } else {
          bdnames.add(elms[i]);
        }
      }

      bdname = bdnames.join(' ').trim();
      dongho = donghos.join(' ').trim();
      auxInfo = auxInfos.join(' ').trim();
    }

    return AddressInfo(
      addrtype: AddressType.Jibun,
      sigungu: sigungudong.trim(),
      bunji: bunji?.replaceAll(' ', '') ?? '',
      address: [sigungudong.trim(), bunji != null ? getBunjiNo(bunji) : '']
          .join(' '),
      bdname: bdname ?? '',
      dongho: dongho ?? '',
      aux: auxInfo ?? '',
      fulladdress: address,
    );
  }

  static String getBunjiNo(String bunji) {
    if (bunji.isNotNullEmptyOrWhitespace) {
      int pos = bunji.indexOf('번지');
      if (pos != -1) bunji = bunji.substring(0, pos);
      pos = bunji.indexOf('외');
      if (pos != -1) bunji = bunji.substring(0, pos);
      return bunji.trim();
    } else {
      return '';
    }
  }

  static final RegExp auxJibunInDoroRegexp = RegExp(r'\[([가-힣A-Z0-9\s\-]+)\]');

  static AddressInfo? splitAddress(String inputAddress) {
    if (inputAddress.isNotNullEmptyOrWhitespace) {
      // 산 번지가 공백이 있는 경우 문제.
      inputAddress = inputAddress.replaceAll(' 산 ', '산');

      String address;
      String? auxJibun;

      var bm = auxJibunInDoroRegexp.firstMatch(inputAddress);
      // [xxxxx] 같은 텍스트 찾아서 aux_part에 넣음
      // 이 부분은 번지 주소임
      if (bm != null) {
        auxJibun = bm.group(0)?.trim();
        if (auxJibun != null && auxJibun[0] == '[')
          auxJibun = auxJibun.substring(1, auxJibun.length - 1);
        address = inputAddress.replaceAll(
            inputAddress.substring(bm.start, bm.end), '');
      } else {
        address = inputAddress;
      }

      AddressInfo? addrInfo;

      if (!isDoroAddress(address)) {
        addrInfo = _splitJibunAddress(address);
      } else {
        addrInfo = _splitDoroAddress(address);
      }

      return addrInfo;
    } else {
      return null;
    }
  }
}

String getShortAddress(String address) {
  if (address == '') return address;
  final words = address.split(' ');
  final sigungu = words.first
      .replaceAll('특별시', '')
      .replaceAll('광역시', '')
      .replaceAll('특별자치', '');
  return [sigungu, ...words.sublist(1)].join(' ');
}
