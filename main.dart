import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile2/home.dart';
import 'package:record/record.dart';
import 'package:charts_flutter/flutter.dart' as charts;

void main() {
  runApp(const
   MaterialApp(
    home: NoiseLevelPage()
   ),
   );
}

class NoiseLevelPage extends StatefulWidget {
  const NoiseLevelPage({super.key});

  @override
  State<NoiseLevelPage> createState() => _NoiseLevelPageState();
}

class _NoiseLevelPageState extends State<NoiseLevelPage> {

  Record myRecording = Record();
  Timer? timer;

  List<charts.Series<NoiseData, int>> seriesList = [];

  double volume = 0.0;
  double minVolume = -45.0;

  double avgVolume = 0.0;
  List<double> volumeList = [];

  bool showFlag = false;

  startTimer() async {
    timer ??= Timer.periodic(
        const Duration(milliseconds: 50), (timer) => updateVolume());
  }

  updateVolume() async {
    Amplitude ampl = await myRecording.getAmplitude();
    if (ampl.current > minVolume) {
      setState(() {
        volume = (ampl.current - minVolume) / minVolume;
        volumeList.add(volume);
        if (volumeList.length > 200) {
          volumeList.removeAt(0);
        }
        updateChart();
        if (volumeList.length >= 200) {
          double sum = volumeList.sublist(volumeList.length - 200).reduce((a, b) => a + b);
          avgVolume = sum / 200;
          if (avgVolume > 70) {
            showFlag = true;
          } else {
            showFlag = false;
          }
        }
      });
    }
  }

  void updateChart() {
    var data = List.generate(volumeList.length, (i) {
      return NoiseData(i, volumeList[i]);
    });
    setState(() {
      seriesList.clear();
      seriesList.add(
        charts.Series<NoiseData, int>(
          id: 'Noise Data',
          colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
          domainFn: (NoiseData data, _) => data.index,
          measureFn: (NoiseData data, _) => data.volume,
          data: data,
        ),
      );
    });
  }

  Future<bool> startRecording() async {
    if (await myRecording.hasPermission()) {
      if (!await myRecording.isRecording()) {
        await myRecording.start();
      }
      startTimer();
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Future<bool> recordFutureBuilder =
    Future<bool>.delayed(const Duration(seconds: 3), (() async {
      return startRecording();
    }));

    return FutureBuilder(
        future: recordFutureBuilder,
        builder: (context, AsyncSnapshot<bool> snapshot) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Noise Level'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: charts.LineChart(
                        seriesList,
                        animate: true,
                        domainAxis: const charts.NumericAxisSpec(
                          tickProviderSpec: charts.StaticNumericTickProviderSpec(
                            <charts.TickSpec<num>>[
                              charts.TickSpec<num>(0, label: '0'),
                              charts.TickSpec<num>(50, label: '50'),
                              charts.TickSpec<num>(100, label: '100'),
                              charts.TickSpec<num>(150, label: '150'),
                              charts.TickSpec<num>(199, label: '200'),
                            ],
                          ),
                        ),
                        primaryMeasureAxis: const charts.NumericAxisSpec(
                          tickProviderSpec: charts.StaticNumericTickProviderSpec(
                            <charts.TickSpec<num>>[
                              charts.TickSpec<num>(0, label: '0'),
                              charts.TickSpec<num>(0.5, label: '0.5'),
                              charts.TickSpec<num>(1, label: '1'),
                              charts.TickSpec<num>(1.5, label: '1.5'),
                              charts.TickSpec<num>(2, label: '2'),
                            ],
                          ),
                        ),
                        behaviors: [
                          charts.ChartTitle('Time (50ms intervals)'),
                          charts.ChartTitle('Noise Level (normalized)'),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    'Average noise level: ${avgVolume.toStringAsFixed(2)} dB',
                    style: const TextStyle(fontSize: 20),
                  ),
                  if (showFlag)
                    const Text(
                      'Red flag!',
                      style: TextStyle(fontSize: 30, color: Colors.red),
                    ),
                ],
              ),
            ),
          );
        });
  }
}

class NoiseData {
  final int index;
  final double volume;

  NoiseData(this.index, this.volume);
}
