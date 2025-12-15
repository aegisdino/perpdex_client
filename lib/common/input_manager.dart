import 'dart:convert';

import 'package:flutter/material.dart';
import 'util.dart';
import 'package:flutter/services.dart';

enum BorderType { None, Underline, Outline }

class InputManager {
  static final InputManager _singleton = InputManager._internal();
  factory InputManager() {
    return _singleton;
  }

  final _textFieldControllers = <String, TextEditingController>{};
  final Map<String, String> _inputs = <String, String>{};
  final List<String> _inputStack = [];
  final Map<String, FocusNode> _textFieldFocusNodes = <String, FocusNode>{};

  Map<String, String> get inputTagMap => _inputs;

  InputManager._internal() {}

  void pushCurrentInputs() {
    _inputStack.add(json.encode(_inputs));
  }

  void popCurrentInputs() {
    if (_inputStack.isNotEmpty) {
      var inputs = json.decode(_inputStack.last);
      inputs.forEach((key, value) {
        _inputs[key] = value.toString();
      });
      _inputStack.removeLast();

      _inputs.forEach((key, value) {
        updateWidgetText(key, value);
      });
    }
  }

  String? getText(String tag) {
    return _inputs[tag];
  }

  int getInt(String tag) {
    try {
      return parseInt(_inputs[tag]);
    } catch (e) {
      return 0;
    }
  }

  double getDouble(String tag) {
    try {
      return parseDouble(_inputs[tag]);
    } catch (e) {
      return 0.0;
    }
  }

  void setText(String tag, String value, {bool updateWidget = true}) {
    _inputs[tag] = value;
    if (updateWidget) {
      updateWidgetText(tag, value);
    }
    //print('setText: $tag, $value, $updateWidget');
  }

  void setTextIfNot(String tag, String value, {bool updateWidget = true}) {
    if (_inputs[tag] != value) {
      setText(tag, value, updateWidget: updateWidget);
    }
  }

  void clearAllTexts() {
    _inputs.forEach((key, value) {
      if (value != '') clearText(key);
    });
  }

  void removeTextsWhere({String? prefix}) {
    if (prefix.isNotNullEmptyOrWhitespace) {
      _inputs.removeWhere((key, value) => key.startsWith(prefix!));
      _textFieldControllers.removeWhere(
        (key, value) => key.startsWith(prefix!),
      );
      _textFieldFocusNodes.removeWhere((key, value) => key.startsWith(prefix!));
    } else {
      _inputs.clear();
      _textFieldControllers.clear();
      _textFieldFocusNodes.clear();
    }
  }

  void removeText(String tag) {
    _inputs.remove(tag);
    _textFieldControllers.remove(tag);
    _textFieldFocusNodes.remove(tag);
  }

  void clearText(String tag) {
    _inputs[tag] = '';
    updateWidgetText(tag, '');
  }

  TextEditingController? getController(String tag) {
    return _textFieldControllers[tag];
  }

  void updateWidgetText(String type, String value) {
    if (_textFieldControllers[type] == null) {
      _textFieldControllers[type] = TextEditingController();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFieldControllers[type]!.value = TextEditingValue(
        text: value,
        selection:
            TextSelection.fromPosition(TextPosition(offset: value.length)),
      );
    });
  }

  void changeTextFormFieldValue(
    String type,
    String newvalue, {
    Function? onChanged,
  }) {
    updateWidgetText(type, newvalue);
    if (_inputs[type] == null) {
      _inputs[type] = newvalue;
    } else if (_inputs[type] != newvalue) {
      _inputs[type] = newvalue;
      if (onChanged != null) {
        onChanged(newvalue);
      }
    }
  }

  bool isFocused(String tag) {
    bool focused = getFocusNode(tag).hasFocus;
    return focused;
  }

  FocusNode getFocusNode(String type) {
    if (!_textFieldFocusNodes.containsKey(type)) {
      _textFieldFocusNodes[type] = FocusNode();
    }
    return _textFieldFocusNodes[type]!;
  }

  void setFocus(String type) {
    _textFieldFocusNodes[type]?.requestFocus();
  }

  // 숫자 스테퍼 위젯 생성
  Widget _buildNumberStepper({
    required String tag,
    required Function(num) onUpdate,
    int min = 0,
    int max = 999,
    int step = 1,
    double? stepperHeight,
    BorderType? borderType,
    bool enabled = true,
  }) {
    return Padding(
      padding: EdgeInsets.all(borderType == BorderType.Outline ? 2 : 0),
      child: SizedBox(
        width: 24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Up button
            InkWell(
              onTap: enabled
                  ? () {
                      String currentText = getText(tag) ?? '0';
                      num currentValue = num.tryParse(currentText) ?? 0;
                      if (currentValue < max) {
                        setText(tag, (currentValue + step).toString());
                        onUpdate(currentValue + step);
                      }
                    }
                  : null,
              child: Container(
                width: 24,
                height: stepperHeight ?? 20,
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        enabled ? Colors.grey.shade300 : Colors.grey.shade200,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  color: enabled ? Colors.white : Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: (stepperHeight ?? 20) - 4,
                  color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            ),
            Container(width: 16, height: 1, color: Colors.grey.shade300),
            // Down button
            InkWell(
              onTap: enabled
                  ? () {
                      String currentText = getText(tag) ?? '0';
                      int currentValue = int.tryParse(currentText) ?? 0;
                      if (currentValue > min) {
                        setText(tag, (currentValue - step).toString());
                        onUpdate(currentValue - step);
                      }
                    }
                  : null,
              child: Container(
                width: 24,
                height: stepperHeight ?? 20,
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        enabled ? Colors.grey.shade300 : Colors.grey.shade200,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  color: enabled ? Colors.white : Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: (stepperHeight ?? 20) - 4,
                  color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List undetected_list = [
    " ",
    "?",
    "/",
    ".",
    ",",
    "<",
    ">",
    "`",
    "~",
    "!",
    "@",
    "#",
    "\$",
    "%",
    "^",
    "*",
    "(",
    ")",
    "_",
    "-",
    "+",
    "=",
    "\\",
    "|",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "0",
  ];

  InputBorder? getBorder(
    BorderType border, {
    double? borderRadius,
  }) {
    switch (border) {
      case BorderType.Outline:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 8.0),
          borderSide: BorderSide.none,
        );

      case BorderType.Underline:
        return UnderlineInputBorder();

      default:
        return InputBorder.none;
    }
  }

  Widget textFormField(
    String type, {
    String? labelText,
    String? hintText,
    String? helperText,
    String? suffix,
    Widget? suffixIcon,
    int maxLines = 1,
    int? maxLength,
    bool expands = false,
    BorderType borderType = BorderType.Outline,
    double? borderRadius,
    InputBorder? inputBorder,
    bool readOnly = false,
    bool dense = true,
    bool autofocus = false,
    double fontSize = 15,
    double? height,
    bool? obscureText,
    bool selectAllOnFocus = false,
    bool enableInteractiveSelection = true,
    Widget? icon,
    Color? cursorColor,
    Color? hintColor,
    Color? fillColor,
    TextStyle? textstyle,
    TextStyle? suffixStyle,
    TextAlign textAlign = TextAlign.left,
    TextAlignVertical verticalAlign = TextAlignVertical.center,
    TextInputType? keyboardType,
    bool? forceWebFocusNode,
    bool? showEraseIcon,
    EdgeInsets? contentPadding,
    ScrollController? scrollController,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
    Function(bool)? onFocusChange,
    Function? onComplete,
    Function? onClear,
    Function(String?)? validator,
    Function(String)? onFieldSubmitted,
    BuildContext? context,
    bool showNumberStepper = false,
    int stepperMin = 0,
    int stepperMax = 999,
    int stepperStep = 1,
    double stepperHeight = 20,
    Function(num)? onStepperChange,
  }) {
    if (keyboardType == null) {
      if (type.contains('email')) {
        keyboardType = TextInputType.emailAddress;
      } else if (type.contains('phone')) {
        keyboardType = TextInputType.phone;
      } else if (type.contains('date')) {
        keyboardType = TextInputType.datetime;
      }
      if (maxLines > 1) keyboardType = TextInputType.multiline;
    }

    final context_ = context ?? ContextManager.buildContext;

    // Number stepper 사용 시 suffixIcon 재정의
    Widget? finalSuffixIcon = suffixIcon;
    if (showEraseIcon == true) {
      finalSuffixIcon = IconButton(
        onPressed: () {
          clearText(type);
          setFocus(type);
          if (onClear != null) onClear();
          if (onChanged != null) onChanged('');
        },
        icon: const Icon(Icons.clear),
      );
    } else if (showNumberStepper) {
      keyboardType = TextInputType.number;
      finalSuffixIcon = _buildNumberStepper(
        tag: type,
        onUpdate: (v) {
          onChanged?.call(v.toString());
          onStepperChange?.call(v);
        },
        min: stepperMin,
        max: stepperMax,
        step: stepperStep,
        stepperHeight: stepperHeight,
        enabled: !readOnly,
        borderType: borderType,
      );
    }

    Widget formField = TextFormField(
      style: textstyle ?? TextStyle(fontSize: fontSize),
      controller: _textFieldControllers[type],
      focusNode: getFocusNode(type),
      readOnly: readOnly,
      showCursor: true,
      cursorColor: cursorColor,
      autofocus: autofocus,
      enableInteractiveSelection: enableInteractiveSelection,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      scrollPadding: context_ != null
          ? EdgeInsets.only(
              bottom: MediaQuery.of(context_).viewInsets.bottom + fontSize * 4,
            )
          : const EdgeInsets.all(20.0),
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        icon: icon,
        fillColor: fillColor,
        filled: fillColor != null,
        labelText: labelText,
        labelStyle: TextStyle(fontSize: 12, color: hintColor ?? Colors.grey),
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 12, color: hintColor ?? Colors.grey),
        helperText: helperText,
        helperStyle: TextStyle(fontSize: 12, color: hintColor ?? Colors.grey),
        suffixText: suffix,
        suffixIcon: finalSuffixIcon,
        suffixStyle: suffixStyle ??
            TextStyle(
              fontSize: 12,
              color: hintColor ?? AppTheme.colorScheme.surface,
            ),
        isDense: dense,
        suffixIconConstraints: BoxConstraints(),
        isCollapsed: false,
        border:
            inputBorder ?? getBorder(borderType, borderRadius: borderRadius),
        constraints: height != null ? BoxConstraints(maxHeight: height) : null,
        contentPadding: contentPadding,
      ),
      onChanged: (value) {
        _inputs[type] = value;
        if (onChanged != null) {
          onChanged(value);
        }
      },
      expands: expands,
      maxLines: expands == true ? null : maxLines,
      maxLength: maxLength,
      obscureText: obscureText == true ||
          (obscureText == null &&
              (type.contains('password') || type.contains('passwd'))),
      keyboardType: keyboardType,
      textInputAction: keyboardType == TextInputType.multiline
          ? TextInputAction.newline
          : TextInputAction.done,
      textAlign: textAlign,
      textAlignVertical: verticalAlign,
      validator: (value) {
        if (validator != null) return validator(value);
        return null;
      },
      onEditingComplete: () {
        if (onComplete != null) onComplete();
      },
      onFieldSubmitted: (value) {
        if (onFieldSubmitted != null) {
          onFieldSubmitted(value);
        }
      },
    );

    final widget = (onFocusChange != null)
        ? Focus(
            child: formField,
            onFocusChange: (hasFocus) {
              onFocusChange(hasFocus);
            },
          )
        : formField;

    return widget;
  }

  Widget inputBuilder(
    String type, {
    String? value,
    String? labelText,
    String? hintText,
    String? helperText,
    String? suffix,
    Widget? suffixIcon,
    int maxLines = 1,
    int? maxLength,
    double fontSize = 15,
    double? height,
    Widget? icon,
    bool expands = false,
    BorderType borderType = BorderType.Outline,
    double? borderRadius,
    bool readOnly = false,
    bool dense = true,
    bool autofocus = false,
    bool? forceWebFocusNode,
    bool? obscureText,
    bool selectAllOnFocus = false,
    bool enableInteractiveSelection = true,
    Color? cursorColor,
    Color? hintColor,
    Color? fillColor,
    bool? showEraseIcon,
    TextStyle? textstyle,
    TextStyle? suffixStyle,
    TextAlign textAlign = TextAlign.left,
    TextAlignVertical verticalAlign = TextAlignVertical.center,
    TextInputType? keyboardType,
    ScrollController? scrollController,
    EdgeInsets? contentPadding,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
    Function(bool)? onFocusChange,
    Function? onClear,
    Function? onComplete,
    Function(String?)? validator,
    Function(String)? onFieldSubmitted,
    BuildContext? context,
    bool showNumberStepper = false,
    int stepperMin = 0,
    int stepperMax = 999,
    int stepperStep = 1,
    double stepperHeight = 20,
    Function(num)? onStepperChange,
  }) {
    if (!_textFieldControllers.containsKey(type)) {
      _textFieldControllers[type] = TextEditingController();
    }
    if (value != null) {
      changeTextFormFieldValue(type, value);
    }

    return textFormField(
      type,
      textAlign: textAlign,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      suffix: suffix,
      suffixIcon: suffixIcon,
      suffixStyle: suffixStyle,
      icon: icon,
      maxLines: maxLines,
      maxLength: maxLength,
      expands: expands,
      readOnly: readOnly,
      dense: dense,
      borderType: borderType,
      borderRadius: borderRadius,
      autofocus: autofocus,
      forceWebFocusNode: forceWebFocusNode,
      hintColor: hintColor,
      enableInteractiveSelection: enableInteractiveSelection,
      textstyle: textstyle,
      selectAllOnFocus: selectAllOnFocus,
      fontSize: fontSize,
      verticalAlign: verticalAlign,
      obscureText: obscureText,
      keyboardType: keyboardType,
      scrollController: scrollController,
      onChanged: onChanged,
      onClear: onClear,
      onFocusChange: onFocusChange,
      onComplete: onComplete,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      cursorColor: cursorColor,
      fillColor: fillColor,
      height: height,
      showEraseIcon: showEraseIcon,
      contentPadding: contentPadding,
      inputFormatters: inputFormatters,
      showNumberStepper: showNumberStepper,
      stepperMin: stepperMin,
      stepperMax: stepperMax,
      stepperStep: stepperStep,
      stepperHeight: stepperHeight,
      onStepperChange: onStepperChange,
    );
  }
}

class UnfocusTouchView extends StatefulWidget {
  final Widget child;
  const UnfocusTouchView({required this.child, super.key});

  @override
  State<UnfocusTouchView> createState() => _UnfocusTouchViewState();
}

class _UnfocusTouchViewState extends State<UnfocusTouchView> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        FocusScope.of(context).unfocus();
      },
      child: widget.child,
    );
  }
}
