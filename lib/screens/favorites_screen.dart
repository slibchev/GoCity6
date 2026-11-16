import 'dart:async';

import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/favorite_place.dart';
import '../models/place_suggestion.dart';
import '../services/backend_places_service.dart';
import '../services/favorites_service.dart';
import '../widgets/city6_app_bar_title.dart';
import '../widgets/language_selector.dart';

class FavoritesScreen extends StatefulWidget {
  final FavoritesService favoritesService;
  final BackendPlacesService placesService;

  const FavoritesScreen({
    super.key,
    this.favoritesService = const FavoritesService(),
    this.placesService = const BackendPlacesService(),
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with AppLanguageAwareState<FavoritesScreen> {
  List<FavoritePlace> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await widget.favoritesService.getFavorites();

    if (!mounted) {
      return;
    }

    setState(() {
      _favorites = favorites;
      _isLoading = false;
    });
  }

  Future<void> _addFavorite() async {
    final favorite = await showDialog<FavoritePlace>(
      context: context,
      builder: (context) {
        return FavoritePlaceDialog(placesService: widget.placesService);
      },
    );

    if (favorite == null) {
      return;
    }

    await widget.favoritesService.addFavorite(favorite);

    await _loadFavorites();
  }

  Future<void> _editFavorite(FavoritePlace favorite) async {
    final updatedFavorite = await showDialog<FavoritePlace>(
      context: context,
      builder: (context) {
        return FavoritePlaceDialog(
          favorite: favorite,
          placesService: widget.placesService,
        );
      },
    );

    if (updatedFavorite == null) {
      return;
    }

    await widget.favoritesService.updateFavorite(updatedFavorite);

    await _loadFavorites();
  }

  Future<void> _deleteFavorite(FavoritePlace favorite) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AnimatedBuilder(
          animation: AppTranslations.languageNotifier,
          builder: (context, _) => AlertDialog(
            title: Text(AppTranslations.favoriteDeleteConfirmationTitle),
            content: Text(
              AppTranslations.favoriteDeleteConfirmationMessage(favorite.name),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: Text(AppTranslations.favoriteCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: Text(AppTranslations.favoriteDelete),
              ),
            ],
          ),
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await widget.favoritesService.deleteFavorite(favorite.id);

    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const City6AppBarTitle(), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFavorite,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(AppTranslations.favoriteAdd),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? _buildEmptyState()
          : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border, size: 72, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              AppTranslations.favoriteEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.favoriteEmptyDescription,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _favorites.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 10);
      },
      itemBuilder: (context, index) {
        final favorite = _favorites[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.star),
            ),
            title: Text(
              favorite.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(favorite.address),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editFavorite(favorite);
                }

                if (value == 'delete') {
                  _deleteFavorite(favorite);
                }
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem(
                    value: 'edit',
                    child: AnimatedBuilder(
                      animation: AppTranslations.languageNotifier,
                      builder: (context, _) => Row(
                        children: [
                          const Icon(Icons.edit_outlined),
                          const SizedBox(width: 12),
                          Text(AppTranslations.favoriteEdit),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: AnimatedBuilder(
                      animation: AppTranslations.languageNotifier,
                      builder: (context, _) => Row(
                        children: [
                          const Icon(Icons.delete_outline),
                          const SizedBox(width: 12),
                          Text(AppTranslations.favoriteDelete),
                        ],
                      ),
                    ),
                  ),
                ];
              },
            ),
          ),
        );
      },
    );
  }
}

class FavoritePlaceDialog extends StatefulWidget {
  final FavoritePlace? favorite;
  final BackendPlacesService placesService;

  const FavoritePlaceDialog({
    super.key,
    this.favorite,
    required this.placesService,
  });

  @override
  State<FavoritePlaceDialog> createState() => _FavoritePlaceDialogState();
}

class _FavoritePlaceDialogState extends State<FavoritePlaceDialog>
    with AppLanguageAwareState<FavoritePlaceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;

  Timer? _debounce;

  List<PlaceSuggestion> _suggestions = [];

  bool _isLoadingSuggestions = false;

  String? _selectedPlaceId;

  bool _nameHasError = false;
  bool _addressHasError = false;

  bool get _isEditing => widget.favorite != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.favorite?.name ?? '');

    _addressController = TextEditingController(
      text: widget.favorite?.address ?? '',
    );

    _selectedPlaceId = widget.favorite?.placeId;
  }

  @override
  void dispose() {
    _debounce?.cancel();

    _nameController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  void _onAddressChanged(String value) {
    _debounce?.cancel();

    _selectedPlaceId = null;

    final query = value.trim();

    setState(() {
      _addressHasError = false;
    });

    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });

      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadSuggestions(query);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final suggestions = await widget.placesService.autocomplete(input: query);

      if (!mounted) {
        return;
      }

      if (_addressController.text.trim() != query) {
        return;
      }

      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    setState(() {
      _addressController.text = suggestion.text;
      _selectedPlaceId = suggestion.placeId;

      _suggestions = [];
      _isLoadingSuggestions = false;

      _addressHasError = false;
    });

    FocusScope.of(context).unfocus();
  }

  void _save() {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    final nameIsValid = name.isNotEmpty;
    final addressIsValid = address.isNotEmpty && _selectedPlaceId != null;

    setState(() {
      _nameHasError = !nameIsValid;
      _addressHasError = !addressIsValid;
    });

    if (!nameIsValid || !addressIsValid) {
      return;
    }

    final favorite = FavoritePlace(
      id:
          widget.favorite?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      address: address,
      placeId: _selectedPlaceId!,
    );

    Navigator.pop(context, favorite);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing
            ? AppTranslations.favoriteEditDialogTitle
            : AppTranslations.favoriteAddDialogTitle,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: AppTranslations.favoriteNameLabel,
                  hintText: AppTranslations.favoriteNameHint,
                  errorText: _nameHasError
                      ? AppTranslations.favoriteNameValidation
                      : null,
                  prefixIcon: const Icon(Icons.label_outline),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_nameHasError) {
                    setState(() {
                      _nameHasError = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                onChanged: _onAddressChanged,
                decoration: InputDecoration(
                  labelText: AppTranslations.favoriteAddressLabel,
                  hintText: AppTranslations.favoriteAddressHint,
                  errorText: _addressHasError
                      ? AppTranslations.favoriteAddressValidation
                      : null,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_isLoadingSuggestions)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: CircularProgressIndicator(),
                ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) {
                      return const Divider(height: 1);
                    },
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];

                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(suggestion.text),
                        onTap: () {
                          _selectSuggestion(suggestion);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(AppTranslations.favoriteCancel),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(
            _isEditing
                ? AppTranslations.favoriteSave
                : AppTranslations.favoriteAdd,
          ),
        ),
      ],
    );
  }
}
