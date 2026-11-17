import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:ngo_app/core/i18n/translator.dart';

/// Available before sign-in as well as from both role home screens.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: t('common.language'),
        icon: const Icon(Icons.language),
        initialValue: context.locale.languageCode,
        onSelected: (language) => context.setLocale(Locale(language)),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'en', child: Text('English')),
          PopupMenuItem(value: 'hi', child: Text('हिन्दी')),
        ],
      );
}
