import 'package:flutter/material.dart';

/// 注册、完善资料、编辑资料等表单输入框共用的内边距与左侧留白。
///
/// InputDecorator 把错误提示摆在 contentPadding.left 的位置：输入框若直接用
/// `left: 16` 给文字做缩进，校验提示就会跟着缩进 16，和标签、边框左侧对不齐。
/// 这里把左内边距设为 0，改用一个 16 宽的空 prefixIcon 把输入文字顶到原位，
/// 输入区观感不变，校验提示则与边框左侧对齐。已有 prefixIcon（如区号选择）的
/// 输入框只需用 [kFormFieldContentPadding]，不再加占位。
const EdgeInsets kFormFieldContentPadding = EdgeInsets.only(top: 5, bottom: 5);

/// 下拉选择框（DropdownButtonFormField）用的内边距：原来是左右各 16，左侧同样改由占位撑开。
const EdgeInsets kFormFieldDropdownContentPadding = EdgeInsets.only(right: 16);

const Widget kFormFieldLeadingSpace = SizedBox(width: 16);

const BoxConstraints kFormFieldLeadingSpaceConstraints = BoxConstraints.tightFor(width: 16);
