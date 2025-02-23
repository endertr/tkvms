import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import 'home_page.dart';

class LocationSelector extends StatefulWidget {
  const LocationSelector({super.key});

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<Country> countries = [];
  List<City> cities = [];
  List<District> districts = [];
  
  Country? selectedCountry;
  City? selectedCity;
  District? selectedDistrict;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _checkExistingLocation();
  }

  Future<void> _checkExistingLocation() async {
    final location = await _dbHelper.getSelectedLocation();
    if (location != null) {
      // Eğer daha önce seçilmiş bir konum varsa direkt ana sayfaya yönlendir
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  Future<void> _loadCountries() async {
    try {
      final countryList = await _apiService.getCountries();
      setState(() {
        countries = countryList;
      });
    } catch (e) {
      _showError('Ülkeler yüklenirken hata oluştu');
    }
  }

  Future<void> _loadCities(int countryId) async {
    try {
      final cityList = await _apiService.getCities(countryId);
      setState(() {
        cities = cityList;
        selectedCity = null;
        districts = [];
        selectedDistrict = null;
      });
    } catch (e) {
      _showError('Şehirler yüklenirken hata oluştu');
    }
  }

  Future<void> _loadDistricts(int cityId) async {
    try {
      final districtList = await _apiService.getDistricts(cityId);
      setState(() {
        districts = districtList;
        selectedDistrict = null;
      });
    } catch (e) {
      _showError('İlçeler yüklenirken hata oluştu');
    }
  }

  Future<void> _downloadAndSaveData() async {
    if (selectedDistrict == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final currentYear = DateTime.now().year;
      final prayerTimes = await _apiService.getPrayerTimes(
        selectedDistrict!.id,
        currentYear,
      );

      await _dbHelper.savePrayerTimes(prayerTimes, selectedDistrict!.id, currentYear);
      await _dbHelper.saveSelectedLocation(selectedDistrict!.id, currentYear);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Veriler indirilirken hata oluştu');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Seçimi'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<Country>(
                  value: selectedCountry,
                  hint: const Text('Ülke Seçiniz'),
                  items: countries.map((country) {
                    return DropdownMenuItem(
                      value: country,
                      child: Text(country.displayName),
                    );
                  }).toList(),
                  onChanged: (Country? value) {
                    setState(() {
                      selectedCountry = value;
                      if (value != null) {
                        _loadCities(value.id);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<City>(
                  value: selectedCity,
                  hint: const Text('Şehir Seçiniz'),
                  items: cities.map((city) {
                    return DropdownMenuItem(
                      value: city,
                      child: Text(city.displayName),
                    );
                  }).toList(),
                  onChanged: selectedCountry == null
                      ? null
                      : (City? value) {
                          setState(() {
                            selectedCity = value;
                            if (value != null) {
                              _loadDistricts(value.id);
                            }
                          });
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<District>(
                  value: selectedDistrict,
                  hint: const Text('İlçe Seçiniz'),
                  items: districts.map((district) {
                    return DropdownMenuItem(
                      value: district,
                      child: Text(district.displayName),
                    );
                  }).toList(),
                  onChanged: selectedCity == null
                      ? null
                      : (District? value) {
                          setState(() {
                            selectedDistrict = value;
                          });
                        },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: selectedDistrict == null ? null : _downloadAndSaveData,
                  child: const Text('Namaz Vakitlerini İndir'),
                ),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
} 