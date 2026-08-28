import 'dart:io';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PostingLocationData {
  final LatLng coordinates;
  final String? area;
  final String city;
  final String state;
  final String country;
  final String address;

  const PostingLocationData({
    required this.coordinates,
    required this.city,
    required this.state,
    required this.country,
    required this.address,
    this.area,
  });

  factory PostingLocationData.saved() {
    final city = HiveUtils.getCityName()?.toString().trim() ?? '';
    final country = HiveUtils.getSelectedCityCountryCode()?.trim() ?? '';
    final latitude = HiveUtils.getSelectedCityLatitude() ?? 25.2048;
    final longitude = HiveUtils.getSelectedCityLongitude() ?? 55.2708;
    final label = city.isNotEmpty ? city : 'Location';
    return PostingLocationData(
      coordinates: LatLng(latitude, longitude),
      area: null,
      city: city,
      state: '',
      country: country,
      address:
          [label, country].where((value) => value.trim().isNotEmpty).join(', '),
    );
  }

  String get label {
    if (area?.trim().isNotEmpty == true) return area!.trim();
    if (city.trim().isNotEmpty) return city.trim();
    return 'Location';
  }

  PostingLocationData copyWith({
    LatLng? coordinates,
    String? area,
    String? city,
    String? state,
    String? country,
    String? address,
  }) {
    return PostingLocationData(
      coordinates: coordinates ?? this.coordinates,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toItemDetails() => {
        'country': country,
        'state': state,
        'city': city,
        if (area != null && area!.isNotEmpty) 'area': area,
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
        'address': address,
      };

  factory PostingLocationData.fromRouteResult(
    Map<dynamic, dynamic> result,
    PostingLocationData fallback,
  ) {
    String? value(String key) {
      final text = result[key]?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    final latitude = (result['latitude'] as num?)?.toDouble();
    final longitude = (result['longitude'] as num?)?.toDouble();
    final area = value('area') ?? fallback.area;
    final city = value('city') ?? fallback.city;
    final state = value('state') ?? fallback.state;
    final country = value('country') ?? fallback.country;
    final returnedParts = [
      value('area'),
      value('city'),
      value('state'),
      value('country'),
    ].whereType<String>().toSet().toList(growable: false);

    return PostingLocationData(
      coordinates: latitude != null && longitude != null
          ? LatLng(latitude, longitude)
          : fallback.coordinates,
      area: area,
      city: city,
      state: state,
      country: country,
      address:
          returnedParts.isEmpty ? fallback.address : returnedParts.join(', '),
    );
  }
}

Future<PostingLocationData?> openPostingLocationPicker(
  BuildContext context,
  PostingLocationData current,
) async {
  final result = await Navigator.pushNamed(
    context,
    Routes.locationMapScreen,
    arguments: {
      'from': 'addItem',
      'latitude': current.coordinates.latitude,
      'longitude': current.coordinates.longitude,
      'area': current.area,
      'city': current.city,
      'state': current.state,
      'country': current.country,
    },
  );
  if (result is! Map) return null;
  return PostingLocationData.fromRouteResult(result, current);
}

class PostingFieldLabel extends StatelessWidget {
  final String label;

  const PostingFieldLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.color.textDefaultColor,
        ),
      ),
    );
  }
}

String? validateRequiredPostingMediaUrl(
  String? value, {
  required bool youtubeOnly,
}) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) {
    return youtubeOnly
        ? 'YouTube URL is required'
        : '360° tour URL is required';
  }
  final uri = Uri.tryParse(input);
  final validScheme = uri?.scheme == 'http' || uri?.scheme == 'https';
  if (uri == null || !validScheme || uri.host.trim().isEmpty) {
    return 'Enter a valid URL starting with http:// or https://';
  }
  if (youtubeOnly) {
    final host = uri.host.toLowerCase();
    final isYouTube = host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com');
    if (!isYouTube) return 'Enter a valid YouTube URL';
  }
  return null;
}

class PostingMediaLinksSection extends StatelessWidget {
  final TextEditingController youtubeController;
  final TextEditingController? tour360Controller;

  const PostingMediaLinksSection({
    super.key,
    required this.youtubeController,
    this.tour360Controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.video_collection_outlined,
                  color: context.color.territoryColor,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Listing media',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Add links buyers can open from your ad',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const PostingFieldLabel('YouTube URL *'),
          _mediaTextField(
            context,
            controller: youtubeController,
            hint: 'https://youtube.com/watch?v=...',
            icon: Icons.play_circle_outline_rounded,
            validator: (value) => validateRequiredPostingMediaUrl(
              value,
              youtubeOnly: true,
            ),
          ),
          if (tour360Controller != null) ...[
            const SizedBox(height: 16),
            const PostingFieldLabel('360° tour URL *'),
            _mediaTextField(
              context,
              controller: tour360Controller!,
              hint: 'https://example.com/virtual-tour',
              icon: Icons.threesixty_rounded,
              validator: (value) => validateRequiredPostingMediaUrl(
                value,
                youtubeOnly: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mediaTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      style: TextStyle(color: context.color.textDefaultColor),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: context.color.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.color.territoryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class PostingPicturesSection extends StatelessWidget {
  final List<File> images;
  final List<String>? existingImages;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int>? onRemoveExisting;
  final bool showMainBadge;

  const PostingPicturesSection({
    super.key,
    required this.images,
    this.existingImages,
    required this.onAdd,
    required this.onRemove,
    this.onRemoveExisting,
    this.showMainBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final netImages = existingImages ?? const [];
    final totalCount = netImages.length + images.length;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFFD31027),
            ),
            label: Text(
              totalCount == 0
                  ? 'Add Pictures'
                  : 'Add More Pictures ($totalCount selected)',
              style: const TextStyle(
                color: Color(0xFFD31027),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD31027), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (totalCount > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: totalCount,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isExisting = index < netImages.length;
                final isMain = showMainBadge && index == 0;

                Widget imageWidget;
                if (isExisting) {
                  imageWidget = ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: UiUtils.getImage(
                      netImages[index],
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  );
                } else {
                  final fileIndex = index - netImages.length;
                  imageWidget = ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      images[fileIndex],
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  );
                }

                return Stack(
                  children: [
                    imageWidget,
                    if (isMain)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Main',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () {
                          if (isExisting) {
                            onRemoveExisting?.call(index);
                          } else {
                            final fileIndex = index - netImages.length;
                            onRemove(fileIndex);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class PostingLocationSection extends StatelessWidget {
  final PostingLocationData location;
  final ValueChanged<PostingLocationData> onChanged;
  final Future<void> Function()? onUseCurrentLocation;
  final bool isLocating;
  final ValueChanged<GoogleMapController>? onMapCreated;

  const PostingLocationSection({
    super.key,
    required this.location,
    required this.onChanged,
    this.onUseCurrentLocation,
    this.isLocating = false,
    this.onMapCreated,
  });

  Future<void> _selectFromMap(BuildContext context) async {
    final selected = await openPostingLocationPicker(context, location);
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: context.color.territoryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ),
              if (onUseCurrentLocation != null)
                TextButton.icon(
                  onPressed: isLocating ? null : onUseCurrentLocation,
                  icon: isLocating
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Locate Me'),
                )
              else
                TextButton.icon(
                  onPressed: () => _selectFromMap(context),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: const Text('Change Pin'),
                ),
            ],
          ),
          Text(
            location.address,
            style: TextStyle(
              fontSize: 12.5,
              color: context.color.textLightColor,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: GoogleMap(
                key: ValueKey(
                  '${location.coordinates.latitude}_${location.coordinates.longitude}',
                ),
                initialCameraPosition: CameraPosition(
                  target: location.coordinates,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('posting_location'),
                    position: location.coordinates,
                    infoWindow: InfoWindow(
                      title: location.label,
                      snippet: location.address,
                    ),
                  ),
                },
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: onMapCreated,
                onTap: (_) => _selectFromMap(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _selectFromMap(context),
              icon: const Icon(Icons.fullscreen_rounded, size: 17),
              label: const Text('Open Full Map'),
            ),
          ),
        ],
      ),
    );
  }
}
