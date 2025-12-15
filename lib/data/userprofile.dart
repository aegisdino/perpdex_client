import 'dart:convert';
import 'package:intl/intl.dart';

import '/common/util.dart';

enum Gender { m, w }

enum BloodType { A, B, AB, O, X }

List<String> piTexts = ['A', 'B', 'AB', 'O', 'X'];

class UserProfile {
  String? name;
  Gender? mw;
  int? birthYear;
  DateTime? birthDate;
  bool? birthTimeKnown;
  BloodType? bloodType;
  int? lunarDateType;
  String? relation;

  bool get isLunarDate {
    return (lunarDateType ?? 0) > 0;
  }

  void clear() {
    name = '';
    mw = Gender.m;
    birthYear = null;
    birthDate = null;
    birthTimeKnown = null;
    bloodType = null;
    lunarDateType = null; // 0: 양, 1: 음, 2: 음(윤)
    relation = null;
  }

  String get personInfo {
    return jsonEncode({
      "name": name,
      "mw": mw.toString().replaceAll("Gender.", ""),
      if (birthDate != null)
        "birthdate": DateFormat("yyyy-MM-dd HH:mm").format(birthDate!),
      if (birthTimeKnown != null) "birthtimeknown": birthTimeKnown,
      if (lunarDateType != null) "lunar": lunarDateType,
      if (birthYear != null) "birthyear": birthYear!,
      if (bloodType != null)
        "bloodtype": bloodType.toString().replaceAll("BloodType.", ""),
      if (relation != null) "relation": relation,
    });
  }

  UserProfile.from(String? jsonText) {
    if (jsonText != null) {
      final personinfo = jsonDecode(jsonText);
      name = personinfo['name'];
      mw = (personinfo['mw'] == 'm' || personinfo['mw'] == '0')
          ? Gender.m
          : Gender.w;

      birthYear = personinfo['birthyear'] as int?;
      if (birthYear != null && birthYear.toString().length > 4)
        birthYear = int.parse(birthYear.toString().substring(0, 4));

      birthDate = personinfo['birthdate'] != null
          ? Util.parseDate(personinfo['birthdate'])
          : null;

      birthTimeKnown = (personinfo['birthtimeknown'] as bool?);
      lunarDateType = personinfo['lunar'];

      if (personinfo['bloodtype'] != null) {
        final index = piTexts.indexOf(personinfo['bloodtype']);
        bloodType = BloodType.values[index == -1 ? 0 : index];
      }

      if (personinfo['relation'] != null) relation = personinfo['relation'];
    }
  }

  UserProfile({
    this.name,
    this.mw,
    this.birthYear,
    this.birthDate,
    this.birthTimeKnown = false,
    this.bloodType,
    this.lunarDateType,
    this.relation,
  });

  int get age {
    if (birthDate != null)
      return DateTime.now().year - birthDate!.year + 1;
    else
      return birthYear != null ? DateTime.now().year - birthYear! + 1 : 0;
  }

  bool get isMale {
    return mw == Gender.m;
  }

  bool get isFemale {
    return mw == Gender.w;
  }

  UserProfile copy() => UserProfile(
        name: name,
        mw: mw,
        bloodType: bloodType,
        birthYear: birthYear,
        birthTimeKnown: birthTimeKnown,
        birthDate: birthDate,
        lunarDateType: lunarDateType,
        relation: relation,
      );
}
