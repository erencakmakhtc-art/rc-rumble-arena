import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../data/world_countries.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';

class SignupScreen extends StatefulWidget {
  final GameController controller;
  const SignupScreen({super.key, required this.controller});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final TextEditingController _nickCtrl;

  @override
  void initState() {
    super.initState();
    _nickCtrl = TextEditingController(text: widget.controller.nick);
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    widget.controller.setNick(v);
    final sanitized = widget.controller.nick;
    if (_nickCtrl.text != sanitized) {
      _nickCtrl.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
  }

  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (chosen != null) widget.controller.setCountry(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selected = worldCountryOf(controller.cc);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('KULLANICI ADI', style: baloo(10, FontWeight.w600, AppColors.inkFaint, letterSpacing: 1.6)),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
              color: Colors.white.withOpacity(0.35),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _nickCtrl,
              onChanged: _onChanged,
              maxLength: 14,
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                isDense: true,
                hintText: 'ör. hizli_kartal',
                hintStyle: baloo(17, FontWeight.w700, AppColors.inkFaint),
              ),
              style: baloo(17, FontWeight.w700, AppColors.ink),
            ),
          ),
          const SizedBox(height: 22),
          Text('ÜLKE', style: baloo(10, FontWeight.w600, AppColors.inkFaint, letterSpacing: 1.6)),
          const SizedBox(height: 8),
          // --- Ulke secici (dropdown; aramali liste acar) ---
          GestureDetector(
            onTap: _pickCountry,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                color: Colors.white.withOpacity(0.35),
              ),
              child: Row(
                children: [
                  if (selected != null) ...[
                    Text(selected.flag, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(selected.name, style: baloo(17, FontWeight.w700, AppColors.ink)),
                    ),
                  ] else
                    Expanded(
                      child: Text('Ülkeni seç', style: baloo(17, FontWeight.w700, AppColors.inkFaint)),
                    ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.inkMuted, size: 26),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          CandyButton(
            onTap: controller.canSignup ? controller.completeSignup : null,
            height: 62,
            borderRadius: 20,
            gradient: controller.canSignup
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE4FFD9), Color(0xFFA8E86A)],
                  )
                : LinearGradient(colors: [Colors.white.withOpacity(0.45), Colors.white.withOpacity(0.45)]),
            depthColor: controller.canSignup ? const Color(0xFF5FA22A) : const Color(0x8C969CCD),
            child: Text(
              'Hesabı oluştur',
              style: baloo(21, FontWeight.w800, controller.canSignup ? AppColors.greenInk : const Color(0xFFA8ADCF)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Şifre yok, e-posta yok. Skorun cihazında saklanır.',
            textAlign: TextAlign.center,
            style: baloo(11, FontWeight.w600, AppColors.inkFaint, height: 1.3),
          ),
          ],
        ),
      ),
    );
  }
}

/// Aranabilir ulke listesi (alttan acilan panel).
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? kWorldCountries
        : kWorldCountries.where((c) => c.name.toLowerCase().contains(q) || c.code.toLowerCase() == q).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF3F4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFC2C6E6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              Text('Ülkeni seç', style: baloo(20, FontWeight.w800, AppColors.ink)),
              const SizedBox(height: 12),
              // arama kutusu
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppColors.inkFaint, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Ülke ara…',
                          hintStyle: baloo(15, FontWeight.w600, AppColors.inkFaint),
                        ),
                        style: baloo(15, FontWeight.w700, AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text('Sonuç yok', style: baloo(15, FontWeight.w600, AppColors.inkFaint)),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final c = items[i];
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(c.code),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              child: Row(
                                children: [
                                  Text(c.flag, style: const TextStyle(fontSize: 26)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(c.name, style: baloo(16, FontWeight.w700, AppColors.inkSoft)),
                                  ),
                                  Text(c.code, style: baloo(12, FontWeight.w600, AppColors.inkFaint)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
