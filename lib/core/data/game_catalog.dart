import 'package:lurk_app/models/game_definition.dart';

// games with their ranks or no ranks
// can add if need to
class GameCatalog {
  static const Map<String, GameDefinition> games = {
    'valorant': GameDefinition(
      id: 'valorant',
      name: 'Valorant',
      iconAsset: 'assets/images/valorant_logo.png',
      ranks: {
        'iron': 'Iron',
        'bronze': 'Bronze',
        'silver': 'Silver',
        'gold': 'Gold',
        'platinum': 'Platinum',
        'diamond': 'Diamond',
        'ascendant': 'Ascendant',
        'immortal': 'Immortal',
        'radiant': 'Radiant',
      },
    ),
    'mobile_legends': GameDefinition(
      id: 'mobile_legends',
      name: 'Mobile Legends',
      iconAsset: 'assets/images/mobile_legends_logo.webp',
      ranks: {
        'warrior': 'Warrior',
        'elite': 'Elite',
        'master': 'Master',
        'grandmaster': 'Grandmaster',
        'epic': 'Epic',
        'legend': 'Legend',
        'mythic': 'Mythic',
        'mythical_honor': 'Mythical Honor',
        'mythical_glory': 'Mythical Glory',
        'mythical_immortal': 'Mythical Immortal',
      },
    ),
    'fortnite': GameDefinition(
      id: 'fortnite',
      name: 'Fortnite',
      iconAsset: 'assets/images/fortnite_logo.png',
    ),
    'apex_legends': GameDefinition(
      id: 'apex_legends',
      name: 'Apex Legends',
      iconAsset: 'assets/images/apex_legends.png',
      ranks: {
        'rookie': 'Rookie',
        'bronze': 'Bronze',
        'silver': 'Silver',
        'gold': 'Gold',
        'platinum': 'Platinum',
        'diamond': 'Diamond',
        'master': 'Master',
        'apex_predator': 'Apex Predator',
      },
    ),
    'cs2': GameDefinition(
      id: 'cs2',
      name: 'Counter-Strike 2',
      iconAsset: 'assets/images/cs2_logo.webp',
      rankHelp:
          'Competitive skill group for your main map. '
          'Premier CS Rating is separate.',
      ranks: {
        'silver_1': 'Silver I',
        'silver_2': 'Silver II',
        'silver_3': 'Silver III',
        'silver_4': 'Silver IV',
        'silver_elite': 'Silver Elite',
        'silver_elite_master': 'Silver Elite Master',
        'gold_nova_1': 'Gold Nova I',
        'gold_nova_2': 'Gold Nova II',
        'gold_nova_3': 'Gold Nova III',
        'gold_nova_master': 'Gold Nova Master',
        'master_guardian_1': 'Master Guardian I',
        'master_guardian_2': 'Master Guardian II',
        'master_guardian_elite': 'Master Guardian Elite',
        'distinguished_master_guardian': 'Distinguished Master Guardian',
        'legendary_eagle': 'Legendary Eagle',
        'legendary_eagle_master': 'Legendary Eagle Master',
        'supreme_master_first_class': 'Supreme Master First Class',
        'global_elite': 'Global Elite',
      },
    ),
    'honor_of_kings': GameDefinition(
      id: 'honor_of_kings',
      name: 'Honor of Kings',
      iconAsset: 'assets/images/honor_of_kings.png',
      ranks: {
        'bronze': 'Bronze',
        'silver': 'Silver',
        'gold': 'Gold',
        'platinum': 'Platinum',
        'diamond': 'Diamond',
        'master': 'Master',
        'grandmaster': 'Grandmaster',
        'mythic': 'Mythic',
        'epic': 'Epic',
        'legend': 'Legend',
      },
    ),
    'league_of_legends': GameDefinition(
      id: 'league_of_legends',
      name: 'League of Legends',
      iconAsset: 'assets/images/league_of_legends_logo.webp',
      ranks: {
        'iron': 'Iron',
        'bronze': 'Bronze',
        'silver': 'Silver',
        'gold': 'Gold',
        'platinum': 'Platinum',
        'emerald': 'Emerald',
        'diamond': 'Diamond',
        'master': 'Master',
        'grandmaster': 'Grandmaster',
        'challenger': 'Challenger',
      },
    ),
    'minecraft': GameDefinition(
      id: 'minecraft',
      name: 'Minecraft',
      iconAsset: 'assets/images/minecraft_logo.png',
    ),
    'roblox': GameDefinition(
      id: 'roblox',
      name: 'Roblox',
      iconAsset: 'assets/images/roblox_logo.png',
    ),
    'peak': GameDefinition(
      id: 'peak',
      name: 'PEAK',
      iconAsset: 'assets/images/peak_logo.jpg',
    ),
  };

  //finds game using either database ID or name
  static GameDefinition? find(String? value) {
    if (value == null) return null;

    final search = value.trim().toLowerCase();

    for (final game in games.values) {
      if (game.id.toLowerCase() == search ||
          game.name.toLowerCase() == search) {
        return game;
      }
    }

    return null;
  }
}
