import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';

class DriverAnalyticsPage extends StatefulWidget {
  final String busId;
  const DriverAnalyticsPage({super.key, required this.busId});

  @override
  State<DriverAnalyticsPage> createState() => _DriverAnalyticsPageState();
}

class _DriverAnalyticsPageState extends State<DriverAnalyticsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final data = await AnalyticsService.getAnalytics(widget.busId);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        title: Text('Bus ${widget.busId} Analytics'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onPrimary),
            onPressed: () {
              setState(() => _loading = true);
              _loadAnalytics();
            },
          )
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final theme = Theme.of(context);
    final total = _data!['total_pickups_today'] ?? 0;
    final statusList = List<Map<String, dynamic>>.from(
        _data!['status_summary'] ?? []);
    final hourlyList = List<Map<String, dynamic>>.from(
        _data!['hourly_data'] ?? []);

    // Get individual status counts
    int completed = 0, pending = 0, cancelled = 0;
    for (var s in statusList) {
      final count = int.tryParse(s['count'].toString()) ?? 0;
      switch (s['status'].toString().toLowerCase()) {
        case 'completed': completed = count; break;
        case 'pending':   pending = count;   break;
        case 'cancelled': cancelled = count; break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

            // ── Today label ──────────────────────────
              Text("Today's Overview",
                style: theme.textTheme.bodySmall!
                  .copyWith(color: theme.colorScheme.onBackground.withOpacity(0.6), letterSpacing: 1.2)),
          const SizedBox(height: 12),

          // ── 3 Stat Cards ─────────────────────────
          Row(
            children: [
                _statCard('Total Pickups', total.toString(),
                  Icons.people_alt, theme.colorScheme.primary),
              const SizedBox(width: 10),
              _statCard('Pending', pending.toString(),
                  Icons.pending, const Color(0xFFFFB74D)),
              const SizedBox(width: 10),
              _statCard('Cancelled', cancelled.toString(),
                  Icons.cancel, const Color(0xFFE57373)),
            ],
          ),
          const SizedBox(height: 24),

          // ── Hourly Chart ──────────────────────────
              Text('Pickups by Hour',
                style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _hourlyChart(hourlyList),
          const SizedBox(height: 24),

          // ── Status Breakdown ──────────────────────
              Text('Status Breakdown',
                style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _statusBreakdown(statusList),
          const SizedBox(height: 24),

          // ── Insight Card ──────────────────────────
          _insightCard(total, pending, cancelled),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: theme.colorScheme.onBackground.withOpacity(0.65), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _hourlyChart(List<Map<String, dynamic>> data) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text('No data yet',
              style: theme.textTheme.bodyMedium!
                  .copyWith(color: theme.colorScheme.onSurface.withOpacity(0.35))),
        ),
      );
    }

    final bars = data.map((d) {
      final hour = double.tryParse(d['hour'].toString()) ?? 0;
      final total = double.tryParse(d['total'].toString()) ?? 0;
      return BarChartGroupData(
        x: hour.toInt(),
        barRods: [
          BarChartRodData(
            toY: total,
              color: Theme.of(context).colorScheme.primary,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );
    }).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: BarChart(BarChartData(
        barGroups: bars,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), strokeWidth: 1),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.45), fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
                getTitlesWidget: (v, _) => Text('${v.toInt()}h',
                  style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.45), fontSize: 10)),
            ),
          ),
          topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
      )),
    );
  }

  Widget _statusBreakdown(List<Map<String, dynamic>> statusList) {
    final colors = {
      'completed': const Color(0xFF81C784),
      'pending': const Color(0xFFFFB74D),
      'cancelled': const Color(0xFFE57373),
    };

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
      ),
      child: Column(
        children: statusList.map((s) {
          final status = s['status'].toString();
          final count = s['count'].toString();
          final color = colors[status.toLowerCase()] ?? Colors.white54;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(status.toUpperCase(),
                    style: TextStyle(
                            color: Colors.black.withOpacity(0.75),
                            fontSize: 13)),
                const Spacer(),
                    Text(count,
                        style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _insightCard(int total, int pending, int cancelled) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.auto_awesome, color: theme.colorScheme.onPrimary, size: 16),
            ),
            const SizedBox(width: 8),
            Text('Smart Insight',
                style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          Text('• $total total pickups for Bus ${widget.busId} today',
              style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 13)),
          const SizedBox(height: 4),
          Text('• $pending passengers still waiting for pickup',
              style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 13)),
          const SizedBox(height: 4),
          Text('• $cancelled pickups were cancelled',
              style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 13)),
        ],
      ),
    );
  }
}
