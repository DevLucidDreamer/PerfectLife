import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../fonts.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';

class TodoTab extends StatefulWidget {
  const TodoTab({super.key});

  @override
  State<TodoTab> createState() => _TodoTabState();
}

class _TodoTabState extends State<TodoTab> {
  bool _showAdd = false;
  final _text = TextEditingController();
  final _tag = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _add() {
    final store = context.read<Store>();
    final text = _text.text.trim();
    if (text.isEmpty) {
      showToast(context, '할 일을 입력하십시오');
      return;
    }
    store.addTodo(text, _tag.text.trim());
    _text.clear();
    _tag.clear();
    setState(() => _showAdd = false);
    showToast(context, '할 일이 추가되었습니다');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final open = store.data.todos.where((t) => !t.done).toList();
    final done = store.data.todos.where((t) => t.done).toList();
    final ordered = [...open, ...done];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        SectionTitle('시험공부 TODO', meta: '남은 일 ${open.length}'),
        GestureDetector(
          onTap: () => setState(() => _showAdd = !_showAdd),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text('+ 할 일 추가',
                style: AppFonts.sans(
                    size: 13, color: AppColors.accentSoft, weight: FontWeight.w600)),
          ),
        ),
        if (_showAdd)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _text,
                  style: AppFonts.sans(size: 13, color: AppColors.ink),
                  decoration:
                      inputDecoration('할 일 (예: SQLD 2과목 JOIN 인강 듣기)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tag,
                  style: AppFonts.sans(size: 13, color: AppColors.ink),
                  decoration: inputDecoration('분류 (선택 · 예: 토익 / SQLD)'),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _add,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('추가하기',
                        style: AppFonts.sans(
                            size: 13, color: AppColors.bg, weight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        if (store.data.todos.isEmpty)
          const EmptyStat('등록된 할 일이 없습니다.\n+ 할 일 추가로 시작하십시오.')
        else
          for (final t in ordered) _TodoRow(todo: t),
      ],
    );
  }
}

class _TodoRow extends StatelessWidget {
  final TodoItem todo;
  const _TodoRow({required this.todo});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => store.toggleTodo(todo.id),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: todo.done ? AppColors.study : Colors.transparent,
                border: Border.all(
                    color: todo.done ? AppColors.study : AppColors.line, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: todo.done
                  ? const Icon(Icons.check, size: 13, color: AppColors.bg)
                  : null,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.text,
                  style: AppFonts.sans(
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: todo.done ? AppColors.inkFaint : AppColors.ink,
                  ).copyWith(
                    decoration: todo.done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (todo.tag.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(todo.tag,
                        style:
                            AppFonts.sans(size: 11, color: AppColors.inkFaint)),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => store.removeTodo(todo.id),
            child: Text('×',
                style: AppFonts.sans(size: 16, color: AppColors.inkFaint)),
          ),
        ],
      ),
    );
  }
}
