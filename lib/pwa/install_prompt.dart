import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../fonts.dart';
import 'pwa_install.dart';

const _snoozeKey = 'pwaPromptSnoozeUntil'; // 이 시각(ms) 전까지는 다시 안 띄움

/// 웹 브라우저로 접속했고(설치된 PWA가 아님) 설치가 가능하면 설치 유도 팝업을 띄운다.
/// 네이티브 앱·이미 설치된 PWA·스누즈 기간 중에는 아무 것도 하지 않는다.
Future<void> maybeShowInstallPrompt(BuildContext context) async {
  if (!kIsWeb) return;
  if (pwaIsStandalone()) return;

  final prefs = await SharedPreferences.getInstance();
  final snoozeUntil = prefs.getInt(_snoozeKey) ?? 0;
  if (DateTime.now().millisecondsSinceEpoch < snoozeUntil) return;

  final ios = pwaIsIos();
  var canInstall = pwaCanInstall();
  if (!ios) {
    // beforeinstallprompt 는 로드 직후 약간 늦게 발화할 수 있어 잠시 대기.
    for (var i = 0; i < 12 && !canInstall; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      canInstall = pwaCanInstall();
    }
    if (!canInstall) return; // 설치 불가(미지원/이미 설치 등) → 띄우지 않음
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _InstallSheet(manual: ios && !canInstall),
  );
}

/// 스토어 카드 형태의 설치 안내 시트.
class _InstallSheet extends StatefulWidget {
  /// true면 iOS처럼 자동 프롬프트가 없어 "홈 화면에 추가" 수동 안내를 보여준다.
  final bool manual;
  const _InstallSheet({required this.manual});

  @override
  State<_InstallSheet> createState() => _InstallSheetState();
}

class _InstallSheetState extends State<_InstallSheet> {
  bool _busy = false;
  bool _showIosGuide = false;

  Future<void> _snooze(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _snoozeKey,
      DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch,
    );
  }

  Future<void> _onInstall() async {
    if (widget.manual) {
      setState(() => _showIosGuide = true);
      return;
    }
    setState(() => _busy = true);
    final outcome = await pwaPromptInstall();
    if (!mounted) return;
    if (outcome == 'accepted') {
      await _snooze(3650); // 설치 완료 → 사실상 다시 안 띄움(다음부턴 standalone)
      if (mounted) Navigator.pop(context);
    } else {
      await _snooze(7); // 거절/불가 → 7일 후 재안내
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onLater() async {
    await _snooze(7);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 아이콘 + 이름 (스토어 헤더)
            Row(
              children: [
                _appIcon(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('오늘부터 갓생',
                          style: AppFonts.sans(
                              size: 17,
                              color: AppColors.ink,
                              weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('갓생 · 루틴 트래커',
                          style: AppFonts.sans(
                              size: 12.5, color: AppColors.inkDim)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_showIosGuide)
              _iosGuide()
            else ...[
              Text('앱으로 설치하면 더 빠르고 편리해요',
                  style: AppFonts.sans(
                      size: 13.5,
                      color: AppColors.ink,
                      weight: FontWeight.w600)),
              const SizedBox(height: 12),
              _feature('홈 화면에서 한 번에 실행'),
              _feature('앱처럼 전체화면으로 쾌적하게'),
              _feature('설치해도 용량 부담 없이 가볍게'),
            ],
            const SizedBox(height: 20),
            _installButton(),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _onLater,
                child: Text('다음에',
                    style:
                        AppFonts.sans(size: 13, color: AppColors.inkFaint)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appIcon() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        'icons/Icon-192.png',
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 64,
          height: 64,
          color: AppColors.panel2,
          alignment: Alignment.center,
          child: Text('갓생',
              style: AppFonts.display(size: 20, color: AppColors.accentSoft)),
        ),
      ),
    );
  }

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_rounded, size: 17, color: AppColors.done),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: AppFonts.sans(size: 13, color: AppColors.inkDim)),
          ),
        ],
      ),
    );
  }

  Widget _iosGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Safari에서 직접 추가해 주세요',
            style: AppFonts.sans(
                size: 13.5, color: AppColors.ink, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        _step(1, '하단의 공유 버튼', Icons.ios_share_rounded),
        _step(2, "'홈 화면에 추가' 선택", Icons.add_box_outlined),
        _step(3, "오른쪽 위 '추가' 누르기", Icons.check_circle_outline),
      ],
    );
  }

  Widget _step(int n, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text('$n',
                style: AppFonts.sans(
                    size: 12,
                    color: AppColors.accentSoft,
                    weight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppFonts.sans(size: 13, color: AppColors.inkDim)),
          ),
          Icon(icon, size: 18, color: AppColors.inkFaint),
        ],
      ),
    );
  }

  Widget _installButton() {
    final label = _showIosGuide
        ? '확인'
        : (widget.manual ? '홈 화면에 추가하기' : '앱 설치하기');
    return GestureDetector(
      onTap: _busy
          ? null
          : (_showIosGuide ? _onLater : _onInstall),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.bg),
              )
            : Text(label,
                style: AppFonts.sans(
                    size: 15,
                    color: AppColors.bg,
                    weight: FontWeight.w700)),
      ),
    );
  }
}
