/// Human-readable labels for internal enum/string values stored in the DB.
class Labels {
  Labels._();

  static String roundType(String v) => switch (v) {
        'welfare' => 'Welfare check',
        'repositioning' => 'Repositioning',
        'continence' => 'Continence check',
        'fluid' => 'Fluid intake',
        'food' => 'Food intake',
        'night' => 'Night check',
        _ => v,
      };

  static String mobility(String v) => switch (v) {
        'independent' => 'Independent',
        'walking_aid' => 'Walking aid',
        'wheelchair' => 'Wheelchair',
        'bedbound' => 'Bedbound',
        _ => v,
      };

  static String careLevel(String v) => switch (v) {
        'residential' => 'Residential',
        'nursing' => 'Nursing',
        'dementia' => 'Dementia',
        'respite' => 'Respite',
        'palliative' => 'Palliative',
        'home_care' => 'Home care',
        _ => v,
      };

  static String fallRisk(String v) => switch (v) {
        'low' => 'Low',
        'medium' => 'Medium',
        'high' => 'High',
        _ => v,
      };

  static String marOutcome(String v) => switch (v) {
        'given' => 'Given',
        'refused' => 'Refused',
        'omitted' => 'Omitted',
        'unavailable' => 'Unavailable',
        'asleep' => 'Asleep',
        'hospital' => 'In hospital',
        _ => v,
      };

  static String medicationRoute(String v) => switch (v) {
        'oral' => 'Oral',
        'topical' => 'Topical',
        'subcutaneous' => 'Subcutaneous',
        'IV' => 'IV',
        'inhaler' => 'Inhaler',
        'patch' => 'Patch',
        'drops' => 'Drops',
        _ => v,
      };

  static String observation(String v) => switch (v) {
        'settled' => 'Settled',
        'asleep' => 'Asleep',
        'awake' => 'Awake',
        'distressed' => 'Distressed',
        _ => v,
      };

  static String position(String v) => switch (v) {
        'left' => 'Left side',
        'right' => 'Right side',
        'back' => 'On back',
        _ => v,
      };
}
