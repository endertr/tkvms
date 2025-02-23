import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prayer_time.dart';
import '../models/location.dart';

class ApiService {
  static const String baseUrl = 'http://semerkandtakvimi.semerkandmobile.com';

  Future<List<Country>> getCountries() async {
    final response = await http.get(Uri.parse('$baseUrl/countries'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Country.fromJson(json)).toList();
    }
    throw Exception('Failed to load countries');
  }

  Future<List<City>> getCities(int countryId) async {
    final response = await http.get(Uri.parse('$baseUrl/cities?countryId=$countryId'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => City.fromJson(json)).toList();
    }
    throw Exception('Failed to load cities');
  }

  Future<List<District>> getDistricts(int cityId) async {
    final response = await http.get(Uri.parse('$baseUrl/districts?cityId=$cityId'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => District.fromJson(json)).toList();
    }
    throw Exception('Failed to load districts');
  }

  Future<List<PrayerTime>> getPrayerTimes(int districtId, int year) async {
    final response = await http.get(
      Uri.parse('$baseUrl/salaattimes?districtId=$districtId&year=$year')
    );
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => PrayerTime.fromJson(json)).toList();
    }
    throw Exception('Failed to load prayer times');
  }
} 