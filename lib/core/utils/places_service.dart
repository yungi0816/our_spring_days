import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class NearbyPlace {
  final String id;
  final String name;
  final String address;
  final LatLng position;
  final String primaryType;

  NearbyPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.primaryType,
  });
}

class PlacesException implements Exception {
  final int statusCode;
  final String message;

  PlacesException(this.statusCode, this.message);

  @override
  String toString() => 'Places API Error $statusCode: $message';
}

class GooglePlacesService {
  static const _nearbySearchUrl =
      'https://places.googleapis.com/v1/places:searchNearby';
  static const _textSearchUrl =
      'https://places.googleapis.com/v1/places:searchText';

  final http.Client _client;

  GooglePlacesService({http.Client? client})
    : _client = client ?? http.Client();

  static bool shouldSearchPlaces(String message) {
    final lower = message.toLowerCase();
    return message.contains('맛집') ||
        message.contains('식당') ||
        message.contains('음식') ||
        message.contains('카페') ||
        message.contains('추천') ||
        message.contains('おすすめ') ||
        message.contains('レストラン') ||
        message.contains('カフェ') ||
        lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('coffee') ||
        lower.contains('place');
  }

  static String primaryTypeForMessage(String message) {
    final lower = message.toLowerCase();
    if (message.contains('카페') ||
        message.contains('カフェ') ||
        lower.contains('cafe') ||
        lower.contains('coffee')) {
      return 'cafe';
    }

    return 'restaurant';
  }

  Future<List<NearbyPlace>> searchNearby({
    required LatLng location,
    required String includedPrimaryType,
    required bool isKorean,
    int maxResultCount = 10,
    double radiusMeters = 3000,
  }) async {
    final response = await _client.post(
      Uri.parse(_nearbySearchUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': AppConstants.googleMapsApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location,places.primaryType',
      },
      body: jsonEncode({
        'includedPrimaryTypes': [includedPrimaryType],
        'maxResultCount': maxResultCount.clamp(1, 20),
        'rankPreference': 'POPULARITY',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': location.latitude,
              'longitude': location.longitude,
            },
            'radius': radiusMeters,
          },
        },
        'languageCode': isKorean ? 'ko' : 'ja',
      }),
    );

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw PlacesException(response.statusCode, _extractErrorMessage(body));
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final places = (data['places'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_toNearbyPlace)
        .where((place) => place != null)
        .cast<NearbyPlace>()
        .toList();

    debugPrint(
      'Places API returned ${places.length} places for $includedPrimaryType',
    );
    return places;
  }

  Future<List<NearbyPlace>> searchPetFriendlyNearby({
    required LatLng location,
    required String includedPrimaryType,
    required bool isKorean,
    int maxResultCount = 10,
  }) {
    return searchText(
      query: _petFriendlyQuery(includedPrimaryType, isKorean),
      isKorean: isKorean,
      locationBias: location,
      maxResultCount: maxResultCount,
      includedType: includedPrimaryType,
    );
  }

  Future<List<NearbyPlace>> searchText({
    required String query,
    required bool isKorean,
    LatLng? locationBias,
    int maxResultCount = 5,
    String? includedType,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [];
    }

    final body = <String, dynamic>{
      'textQuery': trimmedQuery,
      'maxResultCount': maxResultCount.clamp(1, 20),
      'languageCode': isKorean ? 'ko' : 'ja',
    };

    if (includedType != null && includedType.isNotEmpty) {
      body['includedType'] = includedType;
    }

    if (locationBias != null) {
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': locationBias.latitude,
            'longitude': locationBias.longitude,
          },
          'radius': 50000.0,
        },
      };
    }

    final response = await _client.post(
      Uri.parse(_textSearchUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': AppConstants.googleMapsApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location,places.primaryType',
      },
      body: jsonEncode(body),
    );

    final responseBody = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw PlacesException(
        response.statusCode,
        _extractErrorMessage(responseBody),
      );
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    return (data['places'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_toNearbyPlace)
        .where((place) => place != null)
        .cast<NearbyPlace>()
        .toList();
  }

  String _petFriendlyQuery(String includedPrimaryType, bool isKorean) {
    final isCafe = includedPrimaryType == 'cafe';
    if (isKorean) {
      return isCafe ? '애견 동반 카페' : '애견 동반 맛집';
    }
    return isCafe ? 'ペット可 カフェ' : 'ペット可 レストラン';
  }

  NearbyPlace? _toNearbyPlace(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final latitude = (location?['latitude'] as num?)?.toDouble();
    final longitude = (location?['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return null;
    }

    final displayName = json['displayName'] as Map<String, dynamic>?;

    return NearbyPlace(
      id: json['id']?.toString() ?? '$latitude,$longitude',
      name: displayName?['text']?.toString() ?? 'Unknown place',
      address: json['formattedAddress']?.toString() ?? '',
      position: LatLng(latitude, longitude),
      primaryType: json['primaryType']?.toString() ?? '',
    );
  }

  String _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      return error?['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}
