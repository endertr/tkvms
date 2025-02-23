import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/widget_service.dart';

class LocationDialog extends StatefulWidget {
  const LocationDialog({super.key});

  @override
  State<LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<LocationDialog> {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final WidgetService _widgetService = WidgetService();
  
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
    if (selectedDistrict == null || selectedCity == null || selectedCountry == null) return;

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
      
      // Lokasyon detaylarını kaydet
      await _dbHelper.saveLocationDetails(
        districtId: selectedDistrict!.id,
        districtName: selectedDistrict!.displayName,
        cityName: selectedCity!.displayName,
        countryName: selectedCountry!.displayName,
      );

      // WearOS'u güncelle
      await _widgetService.getPrayerTimesForWidget();

      if (mounted) {
        Navigator.of(context).pop(true);
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
    return Dialog(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Konum Seçimi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<Country>(
                  value: selectedCountry,
                  hint: const Text('Ülke Seçiniz'),
                  isExpanded: true,
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
                  isExpanded: true,
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
                  isExpanded: true,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('İptal'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: selectedDistrict == null ? null : _downloadAndSaveData,
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 