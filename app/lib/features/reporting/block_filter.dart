import 'package:flutter/material.dart';
import 'package:ngo_app/core/i18n/translator.dart';

const canonicalBlockNumbers = [3, 7, 14, 19, 27, 29, 32];

class BlockFilter extends StatelessWidget {
  const BlockFilter({super.key, required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        child: DropdownButtonFormField<int>(
          initialValue: value,
          decoration: InputDecoration(labelText: t('reports.block')),
          items: [
            DropdownMenuItem(value: null, child: Text(t('reports.all_blocks'))),
            ...canonicalBlockNumbers.map((number) => DropdownMenuItem(
                value: number,
                child: Text(
                    t('reports.block_number', args: {'number': '$number'})))),
          ],
          onChanged: onChanged,
        ),
      );
}
