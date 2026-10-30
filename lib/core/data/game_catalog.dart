import 'package:lurk_app/models/game_definition.dart';


// games with their ranks or no ranks 
// can add if need to
class GameCatalog {
  static const Map<String, GameDefinition> games = {
    'valorant': GameDefinition(
      id: 'valorant',
      name: 'Valorant',
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
    ),
  };
}