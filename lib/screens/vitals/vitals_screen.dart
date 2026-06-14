import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../models/resident.dart';
import '../../models/vital_reading.dart';
import '../../services/vitals_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';
import 'vitals_form_screen.dart';

/// Vitals history with NEWS2 trend chart.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _readings = await _service.history(widget.resident.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.resident.firstName} · Vitals')),
      body: _loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_readings.length >= 2) _chart(),
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

  Widget _chart() {
    final pts = _readings.reversed.toList();
    final spots = <FlSpot>[];
    for (var i = 0; i < pts.length; i++) {
      spots.add(FlSpot(i.toDouble(), pts[i].news2Score.toDouble()));
    }
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
              height: 180,
              child: LineChart(LineChartData(
                minY: 0,
                titlesData: const FlTitlesData(
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
          ],
        ),
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
