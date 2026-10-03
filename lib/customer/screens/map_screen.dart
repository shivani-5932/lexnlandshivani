import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'plot_detail_screen.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _map = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _plots = [];
  bool _loading = true;
  bool _searching = false;
  Map<String, dynamic>? _selected;

  // Fallback center (Amritsar) used only until plots load.
  static const LatLng _fallback = LatLng(31.6340, 74.8723);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plots = await Api.getMapPlots();
    if (!mounted) return;
    setState(() {
      _plots = plots;
      _loading = false;
    });
    if (plots.isNotEmpty) {
      final p = plots.first;
      _map.move(LatLng(_d(p['lat']), _d(p['lng'])), 11);
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final results = await Api.geocode(q);
    if (!mounted) return;
    setState(() => _searching = false);
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t find "$q"')));
      return;
    }
    final r = results.first;
    _map.move(LatLng(_d(r['lat']), _d(r['lng'])), 12);
    setState(() => _selected = null);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _myLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permission is needed to centre the map')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _map.move(LatLng(pos.latitude, pos.longitude), 14);
    } catch (_) {}
  }

  double _d(dynamic v) => (v as num).toDouble();

  String _price(num v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)} Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    if (v > 0) return '₹${v.toInt()}';
    return 'Ask';
  }

  String _img(String? u) {
    if (u == null || u.isEmpty) return '';
    return u.startsWith('http') ? u : '${Api.mediaBase}$u';
  }

  @override
  Widget build(BuildContext context) {
    final center = _plots.isNotEmpty
        ? LatLng(_d(_plots.first['lat']), _d(_plots.first['lng']))
        : _fallback;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11,
              minZoom: 4,
              maxZoom: 18,
              onTap: (_, __) {
                if (_selected != null) setState(() => _selected = null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lexnland.app',
              ),
              MarkerLayer(
                markers: [
                  for (final p in _plots)
                    Marker(
                      point: LatLng(_d(p['lat']), _d(p['lng'])),
                      width: 46,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = p),
                        child: _PlotPin(
                          active: _selected != null &&
                              _selected!['id'] == p['id'],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Header ──
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 10,
                          offset: Offset(0, 3))
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.search, color: C.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        style: const TextStyle(
                            fontSize: 14, color: C.textDark),
                        decoration: const InputDecoration(
                          hintText: 'Search a place e.g. Amritsar',
                          hintStyle:
                              TextStyle(fontSize: 13.5, color: C.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.all(11),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: C.primary)),
                      )
                    else if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: C.textMuted, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh,
                            color: C.primary, size: 20),
                        onPressed: _load,
                      ),
                  ]),
                ),
              ),
            ]),
          ),

          // ── My location button ──
          Positioned(
            right: 16,
            bottom: _selected != null ? 200 : 28,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _myLocation,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.my_location, color: C.primary, size: 22),
                ),
              ),
            ),
          ),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: C.primary)),

          if (!_loading && _plots.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_off_outlined,
                      size: 44, color: C.textMuted),
                  SizedBox(height: 12),
                  Text('No plots on the map yet',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: C.textDark)),
                  SizedBox(height: 6),
                  Text(
                      'Verified plots with a location pin will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: C.textMuted)),
                ]),
              ),
            ),

          // ── Selected plot card ──
          if (_selected != null)
            Positioned(
                left: 12, right: 12, bottom: 16, child: _card(_selected!)),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final img = _img(p['photo'] as String?);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: img.isEmpty
                ? Container(
                    width: 84,
                    height: 84,
                    color: C.primaryLight,
                    child: const Icon(Icons.landscape_rounded,
                        color: C.primary, size: 30))
                : Image.network(img,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 84,
                        height: 84,
                        color: C.primaryLight,
                        child: const Icon(Icons.landscape_rounded,
                            color: C.primary, size: 30))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p['name']?.toString() ?? 'Plot',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: C.textDark)),
                const SizedBox(height: 2),
                Text(_price((p['price'] as num?) ?? 0),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: C.primary)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: C.textMuted),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(p['location']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12, color: C.textMuted)),
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlotDetailScreen(
                                plotId: p['id'].toString()))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _PlotPin extends StatelessWidget {
  final bool active;
  const _PlotPin({required this.active});
  @override
  Widget build(BuildContext context) {
    final color = active ? C.textDark : C.primary;
    final size = active ? 52.0 : 46.0;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.location_on, size: size, color: color),
        Positioned(
          top: size * 0.2,
          child: Container(
            width: size * 0.30,
            height: size * 0.30,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
