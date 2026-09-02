import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';

class LocationSearchResult {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String? area;
  final String? city;
  final String? state;
  final String? country;

  LocationSearchResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.area,
    this.city,
    this.state,
    this.country,
  });
}

class LocationSearchHelper {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent': 'EbozorApp/1.0 (contact@ebozor.com)',
        'Accept': 'application/json',
      },
    ),
  );

  static Future<List<LocationSearchResult>> search(
    String query, {
    String? defaultCountry,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    log("[LocationSearch] 🔎 Searching places for query: '$trimmed'");
    final List<LocationSearchResult> results = [];
    final Set<String> seenKeys = {};

    void addResult(LocationSearchResult item) {
      final key =
          "${item.latitude.toStringAsFixed(3)},${item.longitude.toStringAsFixed(3)}";
      final titleKey =
          "${item.title.toLowerCase()}_${item.subtitle.toLowerCase()}";
      if (!seenKeys.contains(key) && !seenKeys.contains(titleKey)) {
        seenKeys.add(key);
        seenKeys.add(titleKey);
        results.add(item);
      }
    }

    // 1. Query OpenStreetMap Nominatim for rich worldwide places and addresses
    try {
      final uri =
          Uri.parse("https://nominatim.openstreetmap.org/search").replace(
        queryParameters: {
          'q': trimmed,
          'format': 'json',
          'addressdetails': '1',
          'limit': '6',
        },
      );

      final response = await _dio.getUri(uri);
      if (response.data is List) {
        for (var item in response.data) {
          try {
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat == null || lon == null) continue;

            final address = item['address'] as Map<String, dynamic>? ?? {};
            final displayName = item['display_name']?.toString() ?? '';

            final name = item['name']?.toString() ??
                address['amenity']?.toString() ??
                address['building']?.toString() ??
                address['road']?.toString() ??
                address['suburb']?.toString() ??
                address['neighbourhood']?.toString() ??
                address['city']?.toString() ??
                address['town']?.toString() ??
                address['village']?.toString() ??
                '';

            final area = address['suburb']?.toString() ??
                address['neighbourhood']?.toString() ??
                address['residential']?.toString() ??
                address['road']?.toString();

            final city = address['city']?.toString() ??
                address['town']?.toString() ??
                address['village']?.toString() ??
                address['municipality']?.toString() ??
                address['county']?.toString();

            final state = address['state']?.toString() ??
                address['state_district']?.toString() ??
                address['province']?.toString();

            final country = address['country']?.toString();

            final title = name.isNotEmpty
                ? name
                : (displayName.split(',').take(2).join(',').trim());

            final subtitleParts = [area, city, state, country]
                .where((e) => e != null && e.isNotEmpty && e != title)
                .toSet()
                .toList();

            final subtitle = subtitleParts.isNotEmpty
                ? subtitleParts.join(', ')
                : (displayName.contains(',')
                    ? displayName.split(',').skip(1).take(3).join(',').trim()
                    : '');

            addResult(LocationSearchResult(
              title: title.isNotEmpty ? title : trimmed,
              subtitle: subtitle,
              latitude: lat,
              longitude: lon,
              area: area,
              city: city,
              state: state,
              country: country,
            ));
          } catch (_) {}
        }
        log("[LocationSearch] Nominatim returned ${results.length} places for '$trimmed'");
      }
    } catch (e) {
      log("[LocationSearch] Nominatim search error: $e");
    }

    // 2. Native platform Geocoder (locationFromAddress)
    try {
      List<Location> locations = await Geocoding().locationFromAddress(trimmed);
      for (var loc in locations.take(5)) {
        try {
          List<Placemark> marks = await Geocoding().placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          if (marks.isNotEmpty) {
            for (final mark in marks) {
              final title = [
                mark.name,
                mark.subLocality,
                mark.locality,
              ].where((e) => e != null && e.isNotEmpty).toSet().join(", ");

              final subtitle = [
                mark.administrativeArea,
                mark.country,
              ].where((e) => e != null && e.isNotEmpty).join(", ");

              addResult(LocationSearchResult(
                title: title.isNotEmpty ? title : trimmed,
                subtitle: subtitle,
                latitude: loc.latitude,
                longitude: loc.longitude,
                area: mark.subLocality?.isNotEmpty == true
                    ? mark.subLocality
                    : mark.thoroughfare,
                city: mark.locality?.isNotEmpty == true
                    ? mark.locality
                    : mark.subAdministrativeArea,
                state: mark.administrativeArea,
                country: mark.country,
              ));
            }
          }
        } catch (_) {
          addResult(LocationSearchResult(
            title: trimmed,
            subtitle:
                "${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}",
            latitude: loc.latitude,
            longitude: loc.longitude,
          ));
        }
      }
    } catch (e) {
      log("[LocationSearch] Native geocode error: $e");
    }

    // 3. Fallback with default country
    if (results.length <= 1 &&
        !trimmed.contains(',') &&
        defaultCountry != null &&
        defaultCountry.isNotEmpty) {
      try {
        final locs = await Geocoding().locationFromAddress("$trimmed, $defaultCountry");
        for (var loc in locs.take(4)) {
          try {
            final marks =
                await Geocoding().placemarkFromCoordinates(loc.latitude, loc.longitude);
            if (marks.isNotEmpty) {
              final mark = marks.first;
              final title = [mark.name, mark.subLocality, mark.locality]
                  .where((e) => e != null && e.isNotEmpty)
                  .toSet()
                  .join(", ");
              final subtitle = [mark.administrativeArea, mark.country]
                  .where((e) => e != null && e.isNotEmpty)
                  .join(", ");
              addResult(LocationSearchResult(
                title: title.isNotEmpty ? title : "$trimmed, $defaultCountry",
                subtitle: subtitle,
                latitude: loc.latitude,
                longitude: loc.longitude,
                area: mark.subLocality ?? mark.thoroughfare,
                city: mark.locality ?? mark.subAdministrativeArea,
                state: mark.administrativeArea,
                country: mark.country,
              ));
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    log("[LocationSearch] ✅ Total places found for '$trimmed': ${results.length}\n" +
        results
            .map((r) =>
                "  • ${r.title} | ${r.subtitle} (${r.latitude}, ${r.longitude})")
            .join("\n"));

    return results;
  }
}
