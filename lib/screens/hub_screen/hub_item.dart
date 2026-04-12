import 'package:flutter/material.dart';

enum HubCategory {
  car,
  home,
  health,
  tech,
  pets,
  documents,
  seasonal,
  custom;

  String get label {
    switch (this) {
      case HubCategory.car:
        return 'Car Hub';
      case HubCategory.home:
        return 'Home Hub';
      case HubCategory.health:
        return 'Health Hub';
      case HubCategory.tech:
        return 'Tech Hub';
      case HubCategory.pets:
        return 'Pets Hub';
      case HubCategory.documents:
        return 'Documents Hub';
      case HubCategory.seasonal:
        return 'Seasonal Hub';
      case HubCategory.custom:
        return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case HubCategory.car:
        return Icons.directions_car;
      case HubCategory.home:
        return Icons.home;
      case HubCategory.health:
        return Icons.favorite;
      case HubCategory.tech:
        return Icons.devices;
      case HubCategory.pets:
        return Icons.pets;
      case HubCategory.documents:
        return Icons.description;
      case HubCategory.seasonal:
        return Icons.wb_sunny;
      case HubCategory.custom:
        return Icons.tune;
    }
  }

  Color get color {
    switch (this) {
      case HubCategory.car:
        return Colors.blueAccent;
      case HubCategory.home:
        return Colors.orangeAccent;
      case HubCategory.health:
        return Colors.redAccent;
      case HubCategory.tech:
        return Colors.purpleAccent;
      case HubCategory.pets:
        return Colors.brown;
      case HubCategory.documents:
        return Colors.teal;
      case HubCategory.seasonal:
        return Colors.greenAccent;
      case HubCategory.custom:
        return Colors.blueGrey;
    }
  }

  static HubCategory fromString(String? value) {
    for (final cat in values) {
      if (cat.name == value) return cat;
    }
    return HubCategory.home;
  }
}

class HubItem {
  String id;
  String name;
  HubCategory category;
  String description;
  int frequencyMonths;
  DateTime? lastDoneDate;
  DateTime? nextDueDate;

  HubItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.frequencyMonths,
    this.lastDoneDate,
    this.nextDueDate,
  });

  /// Status based on how close or past the due date is.
  HubStatus get status {
    if (nextDueDate == null) return HubStatus.unknown;
    final now = DateTime.now();
    final daysUntilDue = nextDueDate!.difference(now).inDays;
    if (daysUntilDue < 0) return HubStatus.overdue;
    if (daysUntilDue <= 14) return HubStatus.dueSoon;
    if (daysUntilDue <= 90) return HubStatus.upcoming;
    return HubStatus.ok;
  }
}

enum HubStatus {
  overdue,
  dueSoon, // within 2 weeks
  upcoming, // within 3 months
  ok,
  unknown;

  String get label {
    switch (this) {
      case HubStatus.overdue:
        return 'Overdue';
      case HubStatus.dueSoon:
        return 'Due Soon';
      case HubStatus.upcoming:
        return 'Coming Up';
      case HubStatus.ok:
        return 'All Good';
      case HubStatus.unknown:
        return 'Not Set';
    }
  }

  Color get color {
    switch (this) {
      case HubStatus.overdue:
        return Colors.redAccent;
      case HubStatus.dueSoon:
        return Colors.orangeAccent;
      case HubStatus.upcoming:
        return Colors.amber;
      case HubStatus.ok:
        return Colors.greenAccent;
      case HubStatus.unknown:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case HubStatus.overdue:
        return Icons.error;
      case HubStatus.dueSoon:
        return Icons.warning_amber;
      case HubStatus.upcoming:
        return Icons.schedule;
      case HubStatus.ok:
        return Icons.check_circle;
      case HubStatus.unknown:
        return Icons.help_outline;
    }
  }
}

/// All preset hub items a user can pick from during setup.
class HubPresets {
  static List<HubPreset> get all => const [
        // --- Car Hub ---
        HubPreset(
          name: 'MOT',
          category: HubCategory.car,
          description:
              'Annual roadworthiness test required by law for vehicles over 3 years old. Failure means your car is illegal to drive.',
          frequencyMonths: 12,
          recommendedMonth:
              'Same month every year — check your V5C logbook for the anniversary date.',
        ),
        HubPreset(
          name: 'Car Service',
          category: HubCategory.car,
          description:
              'Regular servicing keeps your car reliable and maintains resale value. Most manufacturers recommend annually or every 12,000 miles.',
          frequencyMonths: 12,
          recommendedMonth:
              'Book 1-2 weeks before your MOT so any issues are caught early.',
        ),
        HubPreset(
          name: 'Road Tax',
          category: HubCategory.car,
          description:
              'Vehicle Excise Duty (VED) — must be paid to legally drive on UK roads. Can be paid monthly or annually.',
          frequencyMonths: 12,
          recommendedMonth:
              'Auto-renews if paying by direct debit. Check your renewal date on the DVLA website.',
        ),
        HubPreset(
          name: 'Car Insurance',
          category: HubCategory.car,
          description:
              'Legally required. Renewing without comparing quotes typically costs 10-30% more. Always shop around 3-4 weeks before expiry.',
          frequencyMonths: 12,
          recommendedMonth:
              'Start comparing quotes 3-4 weeks before your renewal date.',
        ),
        HubPreset(
          name: 'Breakdown Cover',
          category: HubCategory.car,
          description:
              'AA, RAC, Green Flag etc. Prices creep up on auto-renewal — call and haggle or switch for a better deal.',
          frequencyMonths: 12,
          recommendedMonth:
              'Check your renewal date and compare 2-3 weeks before.',
        ),
        HubPreset(
          name: 'Tyre Check / Replacement',
          category: HubCategory.car,
          description:
              'Legal minimum tread depth is 1.6mm. Check tread depth and pressure monthly, replace when worn. Penalty is £2,500 per illegal tyre.',
          frequencyMonths: 6,
          recommendedMonth:
              'Check every 6 months — before winter and before summer.',
        ),
        HubPreset(
          name: 'Windscreen Washer Fluid',
          category: HubCategory.car,
          description:
              'Top up regularly, especially before winter. Running out during a motorway drive is both dangerous and an MOT failure point.',
          frequencyMonths: 3,
          recommendedMonth: 'Top up quarterly — more often in winter.',
        ),

        // --- Home Hub ---
        HubPreset(
          name: 'Boiler Service',
          category: HubCategory.home,
          description:
              'Annual gas safety check keeps your boiler efficient and safe. Required by law for landlords. Prevents carbon monoxide risks.',
          frequencyMonths: 12,
          recommendedMonth:
              'Book in late summer (Aug-Sep) before the winter rush — engineers are cheaper and more available.',
        ),
        HubPreset(
          name: 'Home Insurance Renewal',
          category: HubCategory.home,
          description:
              'Buildings and contents insurance. Like car insurance, loyalty penalties are real — always compare before renewing.',
          frequencyMonths: 12,
          recommendedMonth: 'Compare quotes 3-4 weeks before expiry.',
        ),
        HubPreset(
          name: 'Contents Insurance Renewal',
          category: HubCategory.home,
          description:
              'Covers your belongings against theft, fire, and damage. Often bundled with home insurance but worth checking separately.',
          frequencyMonths: 12,
          recommendedMonth:
              'Review when your home insurance is up — bundle for discounts.',
        ),
        HubPreset(
          name: 'Energy Tariff Review',
          category: HubCategory.home,
          description:
              'Fixed tariffs expire and you get moved to a variable rate (usually more expensive). Check if a better deal is available.',
          frequencyMonths: 12,
          recommendedMonth: 'Check 4-6 weeks before your fixed tariff ends.',
        ),
        HubPreset(
          name: 'Gutter Cleaning',
          category: HubCategory.home,
          description:
              'Blocked gutters cause damp, leaks, and foundation damage. Clear leaves and debris annually, especially after autumn.',
          frequencyMonths: 12,
          recommendedMonth: 'November-December, after the leaves have fallen.',
        ),
        HubPreset(
          name: 'Smoke Alarm / CO Detector Check',
          category: HubCategory.home,
          description:
              'Test monthly, replace batteries annually. Smoke alarms should be replaced entirely every 10 years. Carbon monoxide detectors every 5-7 years.',
          frequencyMonths: 12,
          recommendedMonth:
              'When the clocks change (March/October) is a good reminder.',
        ),
        HubPreset(
          name: 'TV Licence',
          category: HubCategory.home,
          description:
              'Required if you watch live TV or use BBC iPlayer. Currently £169.50/year. Can be paid monthly.',
          frequencyMonths: 12,
          recommendedMonth:
              'Check if you actually need one — you might not if you only use streaming services.',
        ),
        HubPreset(
          name: 'Council Tax',
          category: HubCategory.home,
          description:
              'Runs April to March. Check your band is correct — thousands of homes are in the wrong band. You can appeal for free.',
          frequencyMonths: 12,
          recommendedMonth:
              'New bill arrives in March/April. Check for single-person discount if applicable (25% off).',
        ),
        HubPreset(
          name: 'Chimney Sweep',
          category: HubCategory.home,
          description:
              'Required annually if you use a wood burner or open fire. Prevents chimney fires and carbon monoxide buildup.',
          frequencyMonths: 12,
          recommendedMonth:
              'September — before you start using the fireplace in winter.',
        ),
        HubPreset(
          name: 'Window Cleaning',
          category: HubCategory.home,
          description:
              'Regular cleaning prevents hard water stain buildup that becomes permanent. Every 2-3 months keeps them clear.',
          frequencyMonths: 3,
          recommendedMonth: 'Quarterly — spring, summer, autumn, winter.',
        ),
        HubPreset(
          name: 'Bleeding Radiators',
          category: HubCategory.home,
          description:
              'Air trapped in radiators makes them heat unevenly (cold at the top). Bleeding them takes 5 minutes and saves energy.',
          frequencyMonths: 12,
          recommendedMonth:
              'September-October, before you turn the heating on for winter.',
        ),
        HubPreset(
          name: 'Water Meter Reading',
          category: HubCategory.home,
          description:
              'Submit regular readings to avoid estimated bills. Takes 2 minutes and can save you from a surprise bill.',
          frequencyMonths: 3,
          recommendedMonth: 'Submit quarterly to keep bills accurate.',
        ),
        HubPreset(
          name: 'Fridge/Freezer Defrost & Clean',
          category: HubCategory.home,
          description:
              'Ice buildup makes your freezer work harder and costs more to run. Clean fridge coils too for efficiency.',
          frequencyMonths: 6,
          recommendedMonth:
              'Every 6 months — good excuse to throw out expired food.',
        ),

        // --- Health Hub ---
        HubPreset(
          name: 'Dentist Check-up',
          category: HubCategory.health,
          description:
              'NHS recommends every 6-24 months depending on risk. Catching problems early saves pain and money.',
          frequencyMonths: 6,
          recommendedMonth:
              'Book your next appointment before leaving the current one.',
        ),
        HubPreset(
          name: 'Eye Test',
          category: HubCategory.health,
          description:
              'Recommended every 2 years (annually if over 40 or with existing conditions). Free on the NHS if eligible.',
          frequencyMonths: 24,
          recommendedMonth:
              'Every 2 years. Free for under-16s, over-60s, and those on certain benefits.',
        ),
        HubPreset(
          name: 'Flu Jab',
          category: HubCategory.health,
          description:
              'Free on the NHS if eligible (over 65, pregnant, certain conditions). Otherwise ~£15 at most pharmacies.',
          frequencyMonths: 12,
          recommendedMonth: 'October-November, before flu season peaks.',
        ),
        HubPreset(
          name: 'NHS Prescription Prepayment Certificate',
          category: HubCategory.health,
          description:
              'If you need 4+ prescriptions in 3 months or 12+ in 12 months, a PPC saves money. 12-month PPC is ~£112.',
          frequencyMonths: 12,
          recommendedMonth:
              'Renew before it expires — you can set up auto-renewal.',
        ),
        HubPreset(
          name: 'Health Check / Blood Test',
          category: HubCategory.health,
          description:
              'NHS Health Check is free for 40-74 year olds every 5 years. Good idea to get bloods done periodically regardless.',
          frequencyMonths: 12,
          recommendedMonth: 'Annually — book through your GP.',
        ),

        // --- Tech Hub ---
        HubPreset(
          name: 'Phone Contract Renewal',
          category: HubCategory.tech,
          description:
              'After your minimum term ends, you\'re likely overpaying. Switch to SIM-only or renegotiate for a much cheaper deal.',
          frequencyMonths: 12,
          recommendedMonth:
              'Check your contract end date — switch immediately after.',
        ),
        HubPreset(
          name: 'Broadband Contract End',
          category: HubCategory.tech,
          description:
              'Out-of-contract broadband prices jump significantly. Compare and switch — or call to haggle a retention deal.',
          frequencyMonths: 18,
          recommendedMonth:
              'Start comparing 4-6 weeks before your contract ends.',
        ),
        HubPreset(
          name: 'Software Licence Renewals',
          category: HubCategory.tech,
          description:
              'Antivirus, Office 365, Adobe, etc. Check if you still need them or if a free alternative exists.',
          frequencyMonths: 12,
          recommendedMonth: 'Review before auto-renewal charges hit your card.',
        ),
        HubPreset(
          name: 'Cloud Storage Subscription',
          category: HubCategory.tech,
          description:
              'iCloud, Google One, Dropbox, etc. Check your usage — you might be paying for storage you\'re not using.',
          frequencyMonths: 12,
          recommendedMonth:
              'Review annually — delete old backups to potentially downgrade your plan.',
        ),
        HubPreset(
          name: 'Password & Security Review',
          category: HubCategory.tech,
          description:
              'Change important passwords, review 2FA settings, check for breached accounts at haveibeenpwned.com.',
          frequencyMonths: 6,
          recommendedMonth:
              'Every 6 months. Use a password manager if you don\'t already.',
        ),
        HubPreset(
          name: 'Computer / Phone Backup',
          category: HubCategory.tech,
          description:
              'Back up photos, documents, and important files. If your device died today, what would you lose?',
          frequencyMonths: 3,
          recommendedMonth: 'Quarterly — or set up automatic backups.',
        ),

        // --- Pets Hub ---
        HubPreset(
          name: 'Vet Check-up',
          category: HubCategory.pets,
          description:
              'Annual wellness exam catches health issues early. Includes weight check, teeth, and general health assessment.',
          frequencyMonths: 12,
          recommendedMonth:
              'Book annually — combine with vaccination boosters.',
        ),
        HubPreset(
          name: 'Pet Vaccinations / Boosters',
          category: HubCategory.pets,
          description:
              'Core vaccinations need annual or triennial boosters depending on the vaccine. Check your pet\'s vaccination card.',
          frequencyMonths: 12,
          recommendedMonth:
              'Your vet will send reminders — but don\'t rely on them.',
        ),
        HubPreset(
          name: 'Flea / Worm Treatment',
          category: HubCategory.pets,
          description:
              'Monthly flea treatment and quarterly worming for dogs/cats. Missing doses can lead to infestations.',
          frequencyMonths: 1,
          recommendedMonth:
              'Monthly — set a recurring reminder on the 1st of each month.',
        ),
        HubPreset(
          name: 'Pet Insurance Renewal',
          category: HubCategory.pets,
          description:
              'Premiums increase with age. Review cover annually — but be careful switching as pre-existing conditions won\'t be covered.',
          frequencyMonths: 12,
          recommendedMonth:
              'Compare 3-4 weeks before renewal. Be cautious about switching.',
        ),

        // --- Documents Hub ---
        HubPreset(
          name: 'Passport Renewal',
          category: HubCategory.documents,
          description:
              'Expires every 10 years. Many countries require 6 months validity remaining to enter. Renewal takes 3-10 weeks.',
          frequencyMonths: 120,
          recommendedMonth:
              'Renew 9 months before expiry — you won\'t lose any remaining time.',
        ),
        HubPreset(
          name: 'Driving Licence Photo Renewal',
          category: HubCategory.documents,
          description:
              'Photocard must be renewed every 10 years (the licence itself doesn\'t expire until 70). £14 online, £17 by post.',
          frequencyMonths: 120,
          recommendedMonth:
              'DVLA sends a reminder — but set your own backup reminder.',
        ),
        HubPreset(
          name: 'Tenancy Agreement Renewal',
          category: HubCategory.documents,
          description:
              'Know when your fixed term ends. After that you\'re on a rolling contract — your landlord can increase rent with notice.',
          frequencyMonths: 12,
          recommendedMonth:
              'Review 2-3 months before the end date. Negotiate rent early.',
        ),
        HubPreset(
          name: 'Life Insurance Review',
          category: HubCategory.documents,
          description:
              'Review cover after major life events: new mortgage, baby, pay rise. Make sure beneficiaries are up to date.',
          frequencyMonths: 12,
          recommendedMonth: 'Review annually or after any major life change.',
        ),
        HubPreset(
          name: 'Will Review',
          category: HubCategory.documents,
          description:
              'Review your will after marriages, births, property purchases, or divorces. 60% of UK adults don\'t have one.',
          frequencyMonths: 24,
          recommendedMonth: 'Review every 2 years or after major life changes.',
        ),
        HubPreset(
          name: 'Credit Report Check',
          category: HubCategory.documents,
          description:
              'Check for errors, fraud, and see what lenders see. Free via ClearScore, Credit Karma, or Experian.',
          frequencyMonths: 3,
          recommendedMonth:
              'Quarterly — especially before applying for credit.',
        ),

        // --- Seasonal Hub ---
        HubPreset(
          name: 'Pressure Wash Driveway / Patio',
          category: HubCategory.seasonal,
          description:
              'Algae and moss buildup makes surfaces slippery and damages paving. A spring clean makes a huge difference.',
          frequencyMonths: 12,
          recommendedMonth: 'March-April, as weather improves.',
        ),
        HubPreset(
          name: 'Garden Prep / Lawn Care',
          category: HubCategory.seasonal,
          description:
              'First mow in March, feed the lawn in April, trim hedges before nesting season (March-August). Don\'t cut hedges during nesting.',
          frequencyMonths: 12,
          recommendedMonth: 'March-April for the first big garden session.',
        ),
        HubPreset(
          name: 'Winter Car Prep',
          category: HubCategory.seasonal,
          description:
              'Check antifreeze levels, battery condition, tyre tread, and keep a winter kit in the boot (scraper, torch, blanket).',
          frequencyMonths: 12,
          recommendedMonth: 'October — before the first frost.',
        ),
        HubPreset(
          name: 'Declutter & Charity Shop Run',
          category: HubCategory.seasonal,
          description:
              'Go through wardrobes, cupboards, and storage. Donate what you don\'t use. Less clutter, more space, and a tax-free conscience.',
          frequencyMonths: 6,
          recommendedMonth:
              'Spring (March) and Autumn (September) — seasonal wardrobe switch.',
        ),
        HubPreset(
          name: 'Washing Machine Clean',
          category: HubCategory.seasonal,
          description:
              'Run an empty hot wash with a cleaning tablet or white vinegar monthly. Prevents mould, odours, and extends machine life.',
          frequencyMonths: 1,
          recommendedMonth: 'Monthly — quick and easy maintenance.',
        ),
      ];
}

/// A preset hub item the user can pick during setup.
class HubPreset {
  final String name;
  final HubCategory category;
  final String description;
  final int frequencyMonths;
  final String recommendedMonth;

  const HubPreset({
    required this.name,
    required this.category,
    required this.description,
    required this.frequencyMonths,
    required this.recommendedMonth,
  });

  String get frequencyLabel {
    if (frequencyMonths == 1) return 'Monthly';
    if (frequencyMonths == 3) return 'Quarterly';
    if (frequencyMonths == 6) return 'Every 6 months';
    if (frequencyMonths == 12) return 'Annually';
    if (frequencyMonths == 18) return 'Every 18 months';
    if (frequencyMonths == 24) return 'Every 2 years';
    if (frequencyMonths == 120) return 'Every 10 years';
    return 'Every $frequencyMonths months';
  }
}
