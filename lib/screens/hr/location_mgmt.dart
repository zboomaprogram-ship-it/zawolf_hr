import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';
import '../../services/google_maps_loader_stub.dart'
    if (dart.library.js_interop) '../../services/google_maps_loader_web.dart';
import '../../models/location_model.dart';
import '../../models/user_model.dart';
import '../../features/attendance_locations/data/attendance_location_administration_repository_impl.dart';
import '../../features/attendance_locations/domain/entities/attendance_assignment_option.dart';
import '../../features/attendance_locations/presentation/pages/attendance_location_assignment_page.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';
import '../../utils/user_facing_error.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final LocationService _locationService = LocationService();
  List<LocationModel> _visibleLocations = const [];
  String _visibleLocationsFingerprint = '';

  String _locationFingerprint(Iterable<LocationModel> locations) => locations
      .map(
        (location) => [
          location.locationId,
          location.name,
          location.latitude,
          location.longitude,
          location.geofenceRadiusMeters,
          location.isActive,
        ].join('|'),
      )
      .join('~');

  void _showAddLocationDialog({LocationModel? existingLocation}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AddLocationDialog(
          locationService: _locationService,
          existingLocation: existingLocation,
        );
      },
    );
  }

  Future<void> _openAssignments(List<LocationModel> locations) async {
    try {
      const pageSize = 250;
      const maximumEmployees = 5000;
      final employeeDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
      do {
        var query = FirebaseFirestore.instance
            .collection('users')
            .where('isActive', isEqualTo: true)
            .orderBy(FieldPath.documentId)
            .limit(pageSize);
        if (cursor != null) query = query.startAfterDocument(cursor);
        final page = await query.get();
        employeeDocs.addAll(page.docs);
        cursor = page.docs.isEmpty ? null : page.docs.last;
        if (page.docs.length < pageSize) break;
      } while (employeeDocs.length < maximumEmployees);
      final employees =
          employeeDocs
              .map(UserModel.fromFirestore)
              .map(
                (user) => AttendanceEmployeeOption(
                  uid: user.uid,
                  name: user.displayName,
                  employeeCode: user.employeeId,
                  department: user.department,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttendanceLocationAssignmentPage(
            employees: employees,
            locations: locations
                .where((location) => location.isActive)
                .map(
                  (location) => AttendanceSiteOption(
                    id: location.locationId,
                    name: location.name,
                  ),
                )
                .toList(growable: false),
            repository: AttendanceLocationAdministrationRepositoryImpl(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              error,
              fallback: 'تعذر تحميل الموظفين لإدارة مواقع الحضور.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إدارة المواقع والفروع',
          style: theme.textTheme.headlineMedium!.copyWith(color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: TextButton.icon(
              key: const ValueKey('attendance-multi-location-action'),
              onPressed: _visibleLocations.isEmpty
                  ? null
                  : () => _openAssignments(_visibleLocations),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('إسناد مواقع متعددة'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ZaWolfColors.primaryCyan,
        onPressed: () => _showAddLocationDialog(),
        icon: const Icon(Icons.add, color: ZaWolfColors.background),
        label: Text(
          'إضافة موقع',
          style: theme.textTheme.titleMedium!.copyWith(
            color: ZaWolfColors.background,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<LocationModel>>(
        stream: _locationService.watchActiveLocations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                userFacingError(
                  snapshot.error!,
                  fallback:
                      'تعذر تحميل المواقع حالياً. أعد المحاولة بعد لحظات.',
                ),
                style: const TextStyle(color: ZaWolfColors.error),
              ),
            );
          }

          // Stream collections can be updated by Firestore while Flutter is
          // building this frame.  Keep an immutable snapshot for buttons and
          // map overlays instead of retaining the stream-owned list.
          final locations = List<LocationModel>.unmodifiable(
            List<LocationModel>.of(snapshot.data ?? const <LocationModel>[]),
          );
          final fingerprint = _locationFingerprint(locations);
          if (_visibleLocationsFingerprint != fingerprint) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _visibleLocationsFingerprint == fingerprint) {
                return;
              }
              setState(() {
                _visibleLocations = locations;
                _visibleLocationsFingerprint = fingerprint;
              });
            });
          }
          if (locations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_off,
                    size: 64,
                    color: ZaWolfColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد فروع مضافة بعد',
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط على زر إضافة موقع لتسجيل الفرع الأول',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'بعد إضافة الفرع سيعمل زر «إسناد مواقع متعددة» لتحديد موقعين أو أكثر لكل موظف.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openAssignments(locations),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('إسناد أكثر من موقع حضور للموظفين'),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final loc = locations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      key: ValueKey(loc.locationId),
                      child: WolfCard(
                        hasBorderGlow: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.business_outlined,
                                      color: ZaWolfColors.primaryCyan,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      loc.name,
                                      style: theme.textTheme.titleLarge!
                                          .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: ZaWolfColors.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () => _showAddLocationDialog(
                                        existingLocation: loc,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: ZaWolfColors.error,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('حذف الفرع'),
                                            content: Text(
                                              'هل أنت متأكد من حذف فرع ${loc.name}؟',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('إلغاء'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'حذف',
                                                  style: TextStyle(
                                                    color: ZaWolfColors.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (!context.mounted) return;
                                        if (confirm == true) {
                                          await _locationService.updateLocation(
                                            loc.copyWith(isActive: false),
                                            actorId: FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.uid,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '📍 العنوان: ${loc.address}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '📏 نطاق الأمان (Geofence): ',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ZaWolfColors.primaryCyan.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${loc.geofenceRadiusMeters.toInt()} متر',
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      color: ZaWolfColors.primaryCyan,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(color: ZaWolfColors.surface02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'الموظفون المسجلون بالفرع: ${loc.employeeCount}',
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: ZaWolfColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'GPS: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: ZaWolfColors.textMuted,
                                    fontFamily: 'JetBrains Mono',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AddLocationDialog extends StatefulWidget {
  final LocationService locationService;
  final LocationModel? existingLocation;

  const AddLocationDialog({
    super.key,
    required this.locationService,
    this.existingLocation,
  });

  @override
  State<AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<AddLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  double _radius = 50.0;
  bool _useMap = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final loc = widget.existingLocation;
    _nameController = TextEditingController(text: loc?.name ?? '');
    _addressController = TextEditingController(text: loc?.address ?? '');
    _latController = TextEditingController(
      text: loc?.latitude.toString() ?? '30.0444',
    );
    _lngController = TextEditingController(
      text: loc?.longitude.toString() ?? '31.2357',
    );
    _radius = loc?.geofenceRadiusMeters ?? 50.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _openFullScreenPicker() async {
    final initialLatLng = LatLng(
      double.tryParse(_latController.text) ?? 30.0444,
      double.tryParse(_lngController.text) ?? 31.2357,
    );

    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => FullScreenLocationPicker(
          initialPosition: initialLatLng,
          radiusMeters: _radius,
        ),
      ),
    );

    if (selected == null || !mounted) return;
    _latController.text = selected.latitude.toStringAsFixed(7);
    _lngController.text = selected.longitude.toStringAsFixed(7);
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final lat = double.tryParse(_latController.text) ?? 30.0444;
    final lng = double.tryParse(_lngController.text) ?? 31.2357;

    try {
      if (widget.existingLocation != null) {
        final updated = widget.existingLocation!.copyWith(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          latitude: lat,
          longitude: lng,
          geofenceRadiusMeters: _radius,
        );
        await widget.locationService.updateLocation(
          updated,
          actorId: FirebaseAuth.instance.currentUser?.uid,
        );
      } else {
        final created = LocationModel(
          locationId: '',
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          latitude: lat,
          longitude: lng,
          geofenceRadiusMeters: _radius,
        );
        await widget.locationService.addLocation(
          created,
          actorId: FirebaseAuth.instance.currentUser?.uid,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الموقع: ${userFacingError(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialLatLng = LatLng(
      double.tryParse(_latController.text) ?? 30.0444,
      double.tryParse(_lngController.text) ?? 31.2357,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      backgroundColor: ZaWolfColors.surface01,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.98,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.96,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingLocation != null
                          ? 'تعديل بيانات الفرع'
                          : 'إضافة فرع جديد',
                      style: theme.textTheme.headlineMedium!.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: ZaWolfColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: ZaWolfColors.surface02),
                const SizedBox(height: 12),

                // Name Input
                WolfInputField(
                  controller: _nameController,
                  labelText: 'اسم الفرع / الموقع',
                  englishLabel: 'Branch Name',
                  hintText: 'مثال: المقر الرئيسي بالقاهرة',
                  validator: (val) => val == null || val.isEmpty
                      ? 'يرجى إدخال اسم الفرع'
                      : null,
                ),
                const SizedBox(height: 16),

                // Address Input
                WolfInputField(
                  controller: _addressController,
                  labelText: 'العنوان التفصيلي',
                  englishLabel: 'Address Detail',
                  hintText: 'شارع التسعين، التجمع الخامس',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'يرجى إدخال العنوان' : null,
                ),
                const SizedBox(height: 16),

                // Geofence Radius Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'نطاق الأمان الجغرافي: ${_radius.toInt()} متر',
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'GEOCIRCLE',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: ZaWolfColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _radius,
                  min: 25,
                  max: 200,
                  divisions: 7,
                  activeColor: ZaWolfColors.primaryCyan,
                  inactiveColor: ZaWolfColors.surface02,
                  label: '${_radius.toInt()} متر',
                  onChanged: (val) {
                    setState(() {
                      _radius = val;
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Map vs. Manual Coordinate selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'طريقة تحديد الإحداثيات (GPS)',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: ZaWolfColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _useMap = !_useMap;
                        });
                      },
                      icon: Icon(
                        _useMap ? Icons.edit_note : Icons.map_outlined,
                        color: ZaWolfColors.primaryCyan,
                      ),
                      label: Text(
                        _useMap ? 'إدخال يدوي' : 'التحديد على الخريطة',
                        style: const TextStyle(color: ZaWolfColors.primaryCyan),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_useMap) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ZaWolfColors.surface02),
                      color: ZaWolfColors.surface02.withValues(alpha: 0.35),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: ZaWolfColors.primaryCyan,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${initialLatLng.latitude.toStringAsFixed(6)}, ${initialLatLng.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(color: Colors.white),
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        WolfButton(
                          onPressed: _openFullScreenPicker,
                          text: 'فتح الخريطة بملء الشاشة',
                          secondaryText: 'FULL SCREEN MAP',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '* افتح الخريطة، حرّكها بحرية، ثم اضغط حفظ الموقع.',
                    style: const TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 11,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ] else ...[
                  // Lat/Lng Manual Form Fields
                  Row(
                    children: [
                      Expanded(
                        child: WolfInputField(
                          controller: _latController,
                          labelText: 'خط العرض (Latitude)',
                          hintText: '30.0444',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textDirection: TextDirection.ltr,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'مطلوب';
                            }
                            if (double.tryParse(val) == null) {
                              return 'قيمة غير صالحة';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: WolfInputField(
                          controller: _lngController,
                          labelText: 'خط الطول (Longitude)',
                          hintText: '31.2357',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textDirection: TextDirection.ltr,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'مطلوب';
                            }
                            if (double.tryParse(val) == null) {
                              return 'قيمة غير صالحة';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),

                // Submit / Cancel Actions
                Row(
                  children: [
                    Expanded(
                      child: WolfButton(
                        onPressed: () => Navigator.pop(context),
                        text: 'إلغاء',
                        secondaryText: 'CANCEL',
                        variant: WolfButtonVariant.outline,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: WolfButton(
                        onPressed: _submit,
                        text: 'حفظ الفرع',
                        secondaryText: 'SAVE BRANCH',
                        loading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FullScreenLocationPicker extends StatefulWidget {
  final LatLng initialPosition;
  final double radiusMeters;

  const FullScreenLocationPicker({
    super.key,
    required this.initialPosition,
    required this.radiusMeters,
  });

  @override
  State<FullScreenLocationPicker> createState() =>
      _FullScreenLocationPickerState();
}

class _FullScreenLocationPickerState extends State<FullScreenLocationPicker> {
  GoogleMapController? _controller;
  late LatLng _selectedPosition;
  late final Future<void> _mapReady;
  late Set<Marker> _markers;
  late Set<Circle> _circles;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    _refreshMapOverlays();
    _mapReady = GoogleMapsLoader.ensureLoaded();
  }

  /// The web map plugin can still be iterating an overlay collection after a
  /// frame is built.  Replace immutable snapshots only when the position
  /// changes; do not create mutable overlay collections from [build].
  void _refreshMapOverlays() {
    final position = _selectedPosition;
    _markers = Set<Marker>.unmodifiable(<Marker>{
      Marker(
        markerId: const MarkerId('selected_branch'),
        position: position,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        onDragEnd: _selectPosition,
      ),
    });
    _circles = Set<Circle>.unmodifiable(<Circle>{
      Circle(
        circleId: const CircleId('branch_geofence'),
        center: position,
        radius: widget.radiusMeters,
        strokeColor: ZaWolfColors.primaryCyan,
        strokeWidth: 2,
        fillColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.16),
      ),
    });
  }

  void _selectPosition(LatLng position) {
    if (!mounted) return;
    setState(() {
      _selectedPosition = position;
      _refreshMapOverlays();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVisibleCenter() async {
    final bounds = await _controller?.getVisibleRegion();
    if (bounds == null) return;
    _selectPosition(
      LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      ),
    );
  }

  Future<void> _openExternalMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${_selectedPosition.latitude},${_selectedPosition.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaWolfColors.background,
      appBar: AppBar(
        title: const Text('تحديد موقع الفرع'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _selectedPosition),
            icon: const Icon(Icons.check),
            label: const Text('حفظ الموقع'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _mapReady,
        builder: (context, snapshot) => Stack(
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const ColoredBox(
                color: ZaWolfColors.surface01,
                child: Center(
                  child: CircularProgressIndicator(
                    color: ZaWolfColors.primaryCyan,
                  ),
                ),
              )
            else if (snapshot.hasError)
              _MapLoadFailure(
                onOpenExternalMap: _openExternalMap,
                onKeepCoordinates: () =>
                    Navigator.pop(context, _selectedPosition),
              )
            else
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.initialPosition,
                  zoom: 16,
                ),
                // google_maps_flutter_web may retain and iterate these
                // collections after a frame. Hand it fresh snapshots so a
                // tap/drag state update cannot modify a collection in use.
                markers: Set<Marker>.of(_markers),
                circles: Set<Circle>.of(_circles),
                onMapCreated: (controller) {
                  _controller = controller;
                },
                onTap: _selectPosition,
                // The web plugin can dereference a missing browser-location
                // provider before permission is granted. Branch selection is
                // still fully available through map taps and coordinates.
                myLocationButtonEnabled: !kIsWeb,
                myLocationEnabled: !kIsWeb,
                zoomControlsEnabled: true,
                compassEnabled: true,
                mapToolbarEnabled: true,
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface01.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ZaWolfColors.surface02),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_selectedPosition.latitude.toStringAsFixed(7)}, ${_selectedPosition.longitude.toStringAsFixed(7)}',
                        style: const TextStyle(color: Colors.white),
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: snapshot.hasError
                                  ? _openExternalMap
                                  : _pickVisibleCenter,
                              icon: const Icon(Icons.center_focus_strong),
                              label: Text(
                                snapshot.hasError
                                    ? 'فتح خرائط Google'
                                    : 'اختيار مركز الخريطة',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  Navigator.pop(context, _selectedPosition),
                              icon: const Icon(Icons.check),
                              label: const Text('حفظ'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLoadFailure extends StatelessWidget {
  const _MapLoadFailure({
    required this.onOpenExternalMap,
    required this.onKeepCoordinates,
  });

  final VoidCallback onOpenExternalMap;
  final VoidCallback onKeepCoordinates;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ZaWolfColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 58,
                  color: ZaWolfColors.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  'تعذر تحميل خريطة Google',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تحقق من اتصال الإنترنت وتفعيل Maps JavaScript API '
                  'وسماح مفتاح الويب لنطاق الموقع.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ZaWolfColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onOpenExternalMap,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('فتح خرائط Google'),
                    ),
                    ElevatedButton.icon(
                      onPressed: onKeepCoordinates,
                      icon: const Icon(Icons.check),
                      label: const Text('استخدام الإحداثيات الحالية'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
