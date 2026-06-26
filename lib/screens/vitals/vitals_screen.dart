import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/resident.dart';
import '../../models/vital_reading.dart';
import '../../services/vitals_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';
import 'vitals_form_screen.dart';

/// Vitals history with NEWS2 trend chart and individual vital sparklines.
class VitalsScreen extends StatefulWidget {
  final Resident resident;
  const VitalsScreen({super.key, required this.resident});
  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final _service = VitalsService();
  List<VitalReading> _readings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _readings = await _service.history(widget.resident.id);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.resident.firstName} · Vitals')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_readings.length >= 2) ...[
                      _News2Chart(readings: _readings),
                      const SizedBox(height: 8),
                      _VitalSparklines(readings: _readings),
                      const SizedBox(height: 8),
                    ],
                    ..._readings.map(_tile),
                    if (_readings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No vitals recorded yet')),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_vitals',
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VitalsFormScreen(resident: widget.resident)));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Record vitals'),
      ),
    );
  }

  Widget _tile(VitalReading v) {
    return Card(
      child: ListTile(
        title: Text('NEWS2: ${v.news2Score}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            'RR ${v.respiratoryRate ?? '—'} · SpO₂ ${v.spo2 ?? '—'}% · T ${v.temperature ?? '—'}°C · BP ${v.systolicBp ?? '—'} · HR ${v.heartRate ?? '—'}\n${Fmt.dateTime(v.recordedAt)}'),
        isThreeLine: true,
        trailing:
            StatusPill(label: v.riskBand.toUpperCase(), severity: v.riskBand),
      ),
    );
  }
}

// ── NEWS2 trend with risk-zone bands ─────────────────────────────────────────

class _News2Chart extends StatelessWidget {
  final List<VitalReading> readings;
  const _News2Chart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final pts = readings.reversed.toList();
    final spots = <FlSpot>[
      for (var i = 0; i < pts.length; i++)
        FlSpot(i.toDouble(), pts[i].news2Score.toDouble()),
    ];
    final dateFmt = DateFormat('d MMM');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text('NEWS2 trend',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              height: 190,
              child: LineChart(LineChartData(
                minY: 0,
                maxY: 14,
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(
                      y1: 0, y2: 4,
                      color: AppTheme.ok.withValues(alpha: 0.08),
                    ),
                    HorizontalRangeAnnotation(
                      y1: 4, y2: 6,
                      color: AppTheme.warning.withValues(alpha: 0.10),
                    ),
                    HorizontalRangeAnnotation(
                      y1: 6, y2: 14,
                      color: AppTheme.critical.withValues(alpha: 0.10),
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (pts.length / 4).ceilToDouble().clamp(1, double.infinity),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= pts.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            dateFmt.format(pts[idx].recordedAt),
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 3,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              )),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 0, 0),
              child: Row(
                children: [
                  _Legend(color: AppTheme.ok, label: 'Low 0–4'),
                  SizedBox(width: 12),
                  _Legend(color: AppTheme.warning, label: 'Medium 5–6'),
                  SizedBox(width: 12),
                  _Legend(color: AppTheme.critical, label: 'High 7+'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.4),
                shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}

// ── Individual vital sparklines ───────────────────────────────────────────────

class _VitalSparklines extends StatelessWidget {
  final List<VitalReading> readings;
  const _VitalSparklines({required this.readings});

  @override
  Widget build(BuildContext context) {
    final pts = readings.reversed.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Individual vitals',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _Sparkline(
              label: 'Heart rate (bpm)',
              color: AppTheme.critical,
              pts: pts,
              value: (v) => v.heartRate?.toDouble(),
              normalMin: 51, normalMax: 90,
            ),
            _Sparkline(
              label: 'SpO₂ (%)',
              color: AppTheme.info,
              pts: pts,
              value: (v) => v.spo2?.toDouble(),
              normalMin: 96, normalMax: 100,
              invertWarning: true,
            ),
            _Sparkline(
              label: 'Systolic BP (mmHg)',
              color: AppTheme.primary,
              pts: pts,
              value: (v) => v.systolicBp?.toDouble(),
              normalMin: 111, normalMax: 219,
            ),
            _Sparkline(
              label: 'Temperature (°C)',
              color: AppTheme.warning,
              pts: pts,
              value: (v) => v.temperature,
              normalMin: 36.1, normalMax: 38.0,
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final String label;
  final Color color;
  final List<VitalReading> pts;
  final double? Function(VitalReading) value;
  final double normalMin;
  final double normalMax;
  final bool invertWarning; // true for SpO2 where low is bad

  const _Sparkline({
    required this.label,
    required this.color,
    required this.pts,
    required this.value,
    required this.normalMin,
    required this.normalMax,
    this.invertWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < pts.length; i++) {
      final v = value(pts[i]);
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.length < 2) return const SizedBox.shrink();

    final last = spots.last.y;
    final isNormal = last >= normalMin && last <= normalMax;
    final statusColor = isNormal ? AppTheme.ok : AppTheme.warning;
    final minVal = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPad = (maxVal - minVal) * 0.05 + 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const Spacer(),
              Text(
                last % 1 == 0 ? last.toInt().toString() : last.toStringAsFixed(1),
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: statusColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: LineChart(LineChartData(
              minY: minVal - yPad,
              maxY: maxVal + yPad,
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.08),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}
