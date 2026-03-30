import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../engine/alert_engine.dart';

// ═══════════════════════════════════════════════════════════════
// ALARM OLUŞTURUCU MODALI
// Kompleks kural tabanlı alarm yapılandırması
// ═══════════════════════════════════════════════════════════════
class AlertBuilderModal extends StatefulWidget {
  final String symbol;
  final String coinName;

  const AlertBuilderModal({
    Key? key,
    required this.symbol,
    required this.coinName,
  }) : super(key: key);

  @override
  State<AlertBuilderModal> createState() => _AlertBuilderModalState();
}

class _AlertBuilderModalState extends State<AlertBuilderModal> {
  final _nameCtrl = TextEditingController();
  final List<_ConditionState> _conditions = [];
  AlertLogicOperator _operator = AlertLogicOperator.and;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = '${widget.coinName} Alarm';
    _addCondition();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addCondition() {
    if (_conditions.length >= 4) return;
    setState(() {
      _conditions.add(_ConditionState(
        source: AlertSource.price,
        comparator: AlertComparator.greaterThan,
        value: 0,
      ));
    });
  }

  void _removeCondition(int index) {
    if (_conditions.length <= 1) return;
    setState(() => _conditions.removeAt(index));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;

    final conditions = _conditions.map((c) => AlertCondition(
      source: c.source,
      comparator: c.comparator,
      value: c.value,
    )).toList();

    final rule = AlertRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      symbol: widget.symbol,
      conditions: conditions,
      operator: _operator,
    );

    await AlertEngine().addRule(rule);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
        )),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kAccentOrange.withOpacity(0.2), kRed.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded, color: kAccentOrange, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Alarm Oluştur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(widget.symbol, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35))),
            ]),
          ]),
        ),
        const SizedBox(height: 4),
        // Disclaimer
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kAccentBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kAccentBlue.withOpacity(0.15)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: kAccentBlue.withOpacity(0.6)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Bu bir analiz uyarısıdır, yatırım tavsiyesi değildir.',
              style: TextStyle(fontSize: 10, color: kAccentBlue.withOpacity(0.7), fontStyle: FontStyle.italic),
            )),
          ]),
        ),
        const SizedBox(height: 12),
        // Content
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Alarm adı
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Alarm Adı',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                filled: true,
                fillColor: kCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            // Mantıksal operatör
            if (_conditions.length > 1)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _opButton('VE (AND)', AlertLogicOperator.and),
                  const SizedBox(width: 4),
                  _opButton('VEYA (OR)', AlertLogicOperator.or),
                ]),
              ),
            // Koşullar
            Text('KOŞULLAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.3), letterSpacing: 2)),
            const SizedBox(height: 8),
            ..._conditions.asMap().entries.map((entry) {
              final i = entry.key;
              final cond = entry.value;
              return _buildConditionCard(i, cond);
            }),
            // Koşul ekle butonu
            if (_conditions.length < 4)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _addCondition,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Koşul Ekle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccentOrange,
                    side: BorderSide(color: kAccentOrange.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ]),
        )),
        // Save button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.notifications_active_rounded, size: 18),
              label: const Text('Alarm Kur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _opButton(String label, AlertLogicOperator op) {
    final isSelected = _operator == op;
    return InkWell(
      onTap: () => setState(() => _operator = op),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kAccentBlue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: kAccentBlue.withOpacity(0.4)) : null,
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: isSelected ? kAccentBlue : Colors.white38,
        )),
      ),
    );
  }

  Widget _buildConditionCard(int index, _ConditionState cond) {
    final valueCtrl = TextEditingController(text: cond.value == 0 ? '' : cond.value.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text('#${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kAccentOrange.withOpacity(0.6))),
          const Spacer(),
          if (_conditions.length > 1)
            InkWell(
              onTap: () => _removeCondition(index),
              child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: kRed.withOpacity(0.5)),
            ),
        ]),
        const SizedBox(height: 10),
        // Kaynak seçimi
        Row(children: [
          SizedBox(width: 60, child: Text('Kaynak', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35)))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
              child: DropdownButton<AlertSource>(
                value: cond.source,
                isExpanded: true,
                dropdownColor: kCard,
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                isDense: true,
                items: AlertSource.values.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(AlertCondition(source: s, comparator: AlertComparator.greaterThan, value: 0).sourceLabel),
                )).toList(),
                onChanged: (v) => setState(() => cond.source = v!),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // Operatör
        Row(children: [
          SizedBox(width: 60, child: Text('Koşul', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35)))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
              child: DropdownButton<AlertComparator>(
                value: cond.comparator,
                isExpanded: true,
                dropdownColor: kCard,
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                isDense: true,
                items: AlertComparator.values.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(AlertCondition(source: AlertSource.price, comparator: c, value: 0).comparatorLabel),
                )).toList(),
                onChanged: (v) => setState(() => cond.comparator = v!),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // Değer
        Row(children: [
          SizedBox(width: 60, child: Text('Değer', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35)))),
          Expanded(
            child: TextField(
              controller: valueCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: kAccentOrange, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
                filled: true, fillColor: kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: (v) => cond.value = double.tryParse(v) ?? 0,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ConditionState {
  AlertSource source;
  AlertComparator comparator;
  double value;
  _ConditionState({required this.source, required this.comparator, required this.value});
}

// ═══════════════════════════════════════════════════════════════
// ALARM LİSTESİ MODALI — Mevcut alarmları görüntüle/yönet
// ═══════════════════════════════════════════════════════════════
class AlertListModal extends StatefulWidget {
  final String symbol;

  const AlertListModal({Key? key, required this.symbol}) : super(key: key);

  @override
  State<AlertListModal> createState() => _AlertListModalState();
}

class _AlertListModalState extends State<AlertListModal> {
  List<AlertRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    _rules = AlertEngine().rules.where((r) => r.symbol == widget.symbol).toList();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Center(child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
        )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            const Icon(Icons.notifications_rounded, color: kAccentOrange, size: 20),
            const SizedBox(width: 10),
            const Text('Alarmlarım', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const Spacer(),
            Text('${_rules.length} alarm', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
          ]),
        ),
        Expanded(
          child: _rules.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_off_outlined, size: 48, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 12),
                Text('Henüz alarm kurulmamış', style: TextStyle(color: Colors.white.withOpacity(0.25))),
              ]))
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _rules.length,
                itemBuilder: (ctx, i) {
                  final rule = _rules[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: rule.isActive ? kAccentOrange.withOpacity(0.2) : kBorder),
                    ),
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: rule.isActive ? kEmerald : Colors.white24,
                          boxShadow: rule.isActive ? [BoxShadow(color: kEmerald.withOpacity(0.5), blurRadius: 6)] : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(rule.name, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: rule.isActive ? Colors.white : Colors.white54,
                        )),
                        const SizedBox(height: 2),
                        Text(
                          rule.conditions.map((c) => '${c.sourceLabel} ${c.comparatorLabel} ${c.value}').join(
                            rule.operator == AlertLogicOperator.and ? ' VE ' : ' VEYA '
                          ),
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        if (rule.triggerCount > 0)
                          Text('${rule.triggerCount}x tetiklendi', style: TextStyle(fontSize: 9, color: kAccentOrange.withOpacity(0.5))),
                      ])),
                      // Toggle
                      Switch(
                        value: rule.isActive,
                        onChanged: (_) async {
                          await AlertEngine().toggleRule(rule.id);
                          _loadRules();
                        },
                        activeColor: kAccentOrange,
                      ),
                      // Delete
                      InkWell(
                        onTap: () async {
                          await AlertEngine().removeRule(rule.id);
                          _loadRules();
                        },
                        child: Icon(Icons.delete_outline_rounded, size: 18, color: kRed.withOpacity(0.5)),
                      ),
                    ]),
                  );
                },
              ),
        ),
      ]),
    );
  }
}
