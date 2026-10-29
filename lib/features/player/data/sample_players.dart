import '../models/player_availability.dart';
import '../models/player.dart';

// Sample presence only; replace with backend data when available.
const samplePlayers = [
  Player(
    id: 'player-1',
    region: 'Asia',
    mode: 'Competitive',
    rank: 6,
    style: 'Serious',
    communication: 'Mic required',
    rating: 4.5,
    availability: PlayerAvailability(
      availableNow: true,
      preferredTimes: {'Evening', 'Night'},
      weeklySchedule: [
        WeeklyGamingSlot(weekday: 1, startMinute: 1080, endMinute: 1380),
        WeeklyGamingSlot(weekday: 5, startMinute: 1080, endMinute: 1380),
      ],
    ),
    name: 'Jay',
    currentGame: 'Valorant',
    isActive: true,
  ),
  Player(
    id: 'player-2',
    region: 'Europe',
    mode: 'Casual',
    rank: 2,
    style: 'Fun',
    communication: 'Chat only',
    rating: 4.0,
    availability: PlayerAvailability(
      preferredTimes: {'Morning'},
      weeklySchedule: [
        WeeklyGamingSlot(weekday: 6, startMinute: 540, endMinute: 720),
      ],
    ),
    name: 'Alex',
    isActive: false,
  ),
];
