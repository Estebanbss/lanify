import 'package:flutter/material.dart';

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<Duration> onSeek;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? currentlyPlaying;
  final int currentTrackIndex;
  final int playlistLength;
  final String Function(Duration) formatDuration;
  final Color? backgroundColor;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onStop,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
    required this.currentPosition,
    required this.totalDuration,
    required this.currentlyPlaying,
    required this.currentTrackIndex,
    required this.playlistLength,
    required this.formatDuration,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxPosition = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final safePosition = currentPosition.inMilliseconds
        .clamp(0, maxPosition)
        .toDouble();

    return Container(
      color: backgroundColor ?? Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Cuadro translúcido y slider estilo Aero
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatDuration(currentPosition),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 1,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: const Color.fromARGB(255, 1, 86, 156),
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: const Color.fromARGB(255, 1, 86, 156),
                        overlayColor: const Color.fromARGB(255, 1, 86, 156),
                        // Para el borde del inactiveTrack, usa trackShape personalizado:
                        trackShape: RoundedRectSliderTrackShape(),
                        overlappingShapeStrokeColor: const Color.fromARGB(
                          255,
                          1,
                          86,
                          156,
                        ),
                      ),
                      child: Slider(
                        value: safePosition,
                        min: 0,
                        max: maxPosition,
                        onChanged: totalDuration.inMilliseconds == 0
                            ? null
                            : (value) =>
                                  onSeek(Duration(milliseconds: value.toInt())),
                      ),
                    ),
                  ),
                  Text(
                    formatDuration(totalDuration),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Info de la canción centrada, fuente clara
            if (currentlyPlaying != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        currentlyPlaying!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF2C3E50),
                          fontFamily: 'Segoe UI',
                          letterSpacing: 2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            // Controles circulares con efecto Aero
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                VistaAeroButton(
                  icon: Icons.skip_previous,
                  onTap: onPrevious,
                  tooltip: 'Anterior',
                  secondTheme: true,
                ),
                const SizedBox(width: 8),
                VistaAeroButton(
                  icon: isPlaying ? Icons.pause : Icons.play_arrow,
                  onTap: onPlayPause,
                  tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                  big: true,
                ),
                const SizedBox(width: 8),
                VistaAeroButton(
                  icon: Icons.skip_next,
                  onTap: onNext,
                  secondTheme: true,
                  tooltip: 'Siguiente',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VistaAeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool big;
  final bool secondTheme;

  const VistaAeroButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.big = false,
    this.secondTheme = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: secondTheme
            ? Colors.white.withValues(alpha: 0.2)
            : const Color.fromARGB(255, 1, 86, 156),
        shape: const CircleBorder(),
        elevation: 36,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(big ? 20 : 8),
            child: Icon(
              icon,
              size: 26,
              color: secondTheme ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
