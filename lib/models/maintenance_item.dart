import 'package:flutter/material.dart';

enum MaintenanceCategory {
  car,
  home,
  health,
  tech,
  pets,
  documents,
  seasonal;

  String get label {
    switch (this) {
      case MaintenanceCategory.car:
        return 'Car';
      case MaintenanceCategory.home:
        return 'Home';
      case MaintenanceCategory.health:
        return 'Health';
      case MaintenanceCategory.tech:
        return 'Tech & Subscriptions';
      case MaintenanceCategory.pets:
        return 'Pets';
      case MaintenanceCategory.documents:
        return 'Documents & Legal';
      case MaintenanceCategory.seasonal:
        return 'Seasonal';
    }
  }

  IconData get icon {
    switch (this) {
      case MaintenanceCategory.car:
        return Icons.directions_car;
      case MaintenanceCategory.home:
        return Icons.home;
      case MaintenanceCategory.health:
        return Icons.favorite;
      case MaintenanceCategory.tech:
        return Icons.devices;
      case MaintenanceCategory.pets:
        return Icons.pets;
      case MaintenanceCategory.documents:
        return Icons.description;
      case MaintenanceCategory.seasonal:
        return Icons.wb_sunny;
    }
  }

  Color get color {
    switch (this) {
      case MaintenanceCategory.car:
        return Colors.blueAccent;
      case MaintenanceCategory.home:
        return Colors.orangeAccent;
      case MaintenanceCategory.health:
        return Colors.redAccent;
      case MaintenanceCategory.tech:
        return Colors.purpleAccent;
      case MaintenanceCategory.pets:
        return Colors.brown;
      case MaintenanceCategory.documents:
        return Colors.teal;
      case MaintenanceCategory.seasonal:
        return Colors.greenAccent;
    }
  }

  static MaintenanceCategory fromString(String? value) {
    for (final cat in values) {
      if (cat.name == value) return cat;
    }
    return MaintenanceCategory.home;
  }
}

class MaintenanceItem {
  String id;
  String name;
  MaintenanceCategory category;
  String description;
  int frequencyMonths;
  DateTime? lastDoneDate;
  DateTime? nextDueDate;

  MaintenanceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.frequencyMonths,
    this.lastDoneDate,
    this.nextDueDate,
  });

  /// Status based on how close or past the due date is.
  MaintenanceStatus get status {
    if (nextDueDate == null) return MaintenanceStatus.unknown;
    final now = DateTime.now();
    final daysUntilDue = nextDueDate!.difference(now).inDays;
    if (daysUntilDue < 0) return MaintenanceStatus.overdue;
    if (daysUntilDue <= 14) return MaintenanceStatus.dueSoon;
    if (daysUntilDue <= 90) return MaintenanceStatus.upcoming;
    return MaintenanceStatus.ok;
  }
}

enum MaintenanceStatus {
  overdue,
  dueSoon,   // within 2 weeks
  upcoming,  // within 3 months
  ok,
  unknown;

  String get label {
    switch (this) {
      case MaintenanceStatus.overdue:
        return 'Overdue';
      case MaintenanceStatus.dueSoon:
        return 'Due Soon';
      case MaintenanceStatus.upcoming:
        return 'Coming Up';
      case MaintenanceStatus.ok:
        return 'All Good';
      case MaintenanceStatus.unknown:
        return 'Not Set';
    }
  }

  Color get color {
    switch (this) {
      case MaintenanceStatus.overdue:
        return Colors.redAccent;
      case MaintenanceStatus.dueSoon:
        return Colors.orangeAccent;
      case MaintenanceStatus.upcoming:
        return Colors.amber;
      case MaintenanceStatus.ok:
        return Colors.greenAccent;
      case MaintenanceStatus.unknown:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case MaintenanceStatus.overdue:
        return Icons.error;
      case MaintenanceStatus.dueSoon:
        return Icons.warning_amber;
      case MaintenanceStatus.upcoming:
        return Icons.schedule;
      case MaintenanceStatus.ok:
        return Icons.check_circle;
      case MaintenanceStatus.unknown:
        return Icons.help_outline;
    }
  }
}

/// All preset maintenance items a user can pick from during setup.
class MaintenancePresets {
  static List<MaintenancePreset> get all => const [
    // --- Car ---
    MaintenancePreset(
      name: 'MOT',
      category: MaintenanceCategory.car,
      description: 'Annual roadworthiness test required by law for vehicles over 3 years old. Failure means your car is illegal to drive.',
      frequencyMonths: 12,
      recommendedMonth: 'Same month every year — check your V5C logbook for the anniversary date.',
    ),
    MaintenancePreset(
      name: 'Car Service',
      category: MaintenanceCategory.car,
      description: 'Regular servicing keeps your car reliable and maintains resale value. Most manufacturers recommend annually or every 12,000 miles.',
      frequencyMonths: 12,
      recommendedMonth: 'Book 1-2 weeks before your MOT so any issues are caught early.',
    ),
    MaintenancePreset(
      name: 'Road Tax',
      category: MaintenanceCategory.car,
      description: 'Vehicle Excise Duty (VED) — must be paid to legally drive on UK roads. Can be paid monthly or annually.',
      frequencyMonths: 12,
      recommendedMonth: 'Auto-renews if paying by direct debit. Check your renewal date on the DVLA website.',
    ),
    MaintenancePreset(
      name: 'Car Insurance',
      category: MaintenanceCategory.car,
      description: 'Legally required. Renewing without comparing quotes typically costs 10-30% more. Always shop around 3-4 weeks before expiry.',
      frequencyMonths: 12,
      recommendedMonth: 'Start comparing quotes 3-4 weeks before your renewal date.',
    ),
    MaintenancePreset(
      name: 'Breakdown Cover',
      category: MaintenanceCategory.car,
      description: 'AA, RAC, Green Flag etc. Prices creep up on auto-renewal — call and haggle or switch for a better deal.',
      frequencyMonths: 12,
      recommendedMonth: 'Check your renewal date and compare 2-3 weeks before.',
    ),
    MaintenancePreset(
      name: 'Tyre Check / Replacement',
      category: MaintenanceCategory.car,
      description: 'Legal minimum tread depth is 1.6mm. Check tread depth and pressure monthly, replace when worn. Penalty is £2,500 per illegal tyre.',
      frequencyMonths: 6,
      recommendedMonth: 'Check every 6 months — before winter and before summer.',
    ),
    MaintenancePreset(
      name: 'Windscreen Washer Fluid',
      category: MaintenanceCategory.car,
      description: 'Top up regularly, especially before winter. Running out during a motorway drive is both dangerous and an MOT failure point.',
      frequencyMonths: 3,
      recommendedMonth: 'Top up quarterly — more often in winter.',
    ),

    // --- Home ---
    MaintenancePreset(
      name: 'Boiler Service',
      category: MaintenanceCategory.home,
      description: 'Annual gas safety check keeps your boiler efficient and safe. Required by law for landlords. Prevents carbon monoxide risks.',
      frequencyMonths: 12,
      recommendedMonth: 'Book in late summer (Aug-Sep) before the winter rush — engineers are cheaper and more available.',
    ),
    MaintenancePreset(
      name: 'Home Insurance Renewal',
      category: MaintenanceCategory.home,
      description: 'Buildings and contents insurance. Like car insurance, loyalty penalties are real — always compare before renewing.',
      frequencyMonths: 12,
      recommendedMonth: 'Compare quotes 3-4 weeks before expiry.',
    ),
    MaintenancePreset(
      name: 'Contents Insurance Renewal',
      category: MaintenanceCategory.home,
      description: 'Covers your belongings against theft, fire, and damage. Often bundled with home insurance but worth checking separately.',
      frequencyMonths: 12,
      recommendedMonth: 'Review when your home insurance is up — bundle for discounts.',
    ),
    MaintenancePreset(
      name: 'Energy Tariff Review',
      category: MaintenanceCategory.home,
      description: 'Fixed tariffs expire and you get moved to a variable rate (usually more expensive). Check if a better deal is available.',
      frequencyMonths: 12,
      recommendedMonth: 'Check 4-6 weeks before your fixed tariff ends.',
    ),
    MaintenancePreset(
      name: 'Gutter Cleaning',
      category: MaintenanceCategory.home,
      description: 'Blocked gutters cause damp, leaks, and foundation damage. Clear leaves and debris annually, especially after autumn.',
      frequencyMonths: 12,
      recommendedMonth: 'November-December, after the leaves have fallen.',
    ),
    MaintenancePreset(
      name: 'Smoke Alarm / CO Detector Check',
      category: MaintenanceCategory.home,
      description: 'Test monthly, replace batteries annually. Smoke alarms should be replaced entirely every 10 years. Carbon monoxide detectors every 5-7 years.',
      frequencyMonths: 12,
      recommendedMonth: 'When the clocks change (March/October) is a good reminder.',
    ),
    MaintenancePreset(
      name: 'TV Licence',
      category: MaintenanceCategory.home,
      description: 'Required if you watch live TV or use BBC iPlayer. Currently £169.50/year. Can be paid monthly.',
      frequencyMonths: 12,
      recommendedMonth: 'Check if you actually need one — you might not if you only use streaming services.',
    ),
    MaintenancePreset(
      name: 'Council Tax',
      category: MaintenanceCategory.home,
      description: 'Runs April to March. Check your band is correct — thousands of homes are in the wrong band. You can appeal for free.',
      frequencyMonths: 12,
      recommendedMonth: 'New bill arrives in March/April. Check for single-person discount if applicable (25% off).',
    ),
    MaintenancePreset(
      name: 'Chimney Sweep',
      category: MaintenanceCategory.home,
      description: 'Required annually if you use a wood burner or open fire. Prevents chimney fires and carbon monoxide buildup.',
      frequencyMonths: 12,
      recommendedMonth: 'September — before you start using the fireplace in winter.',
    ),
    MaintenancePreset(
      name: 'Window Cleaning',
      category: MaintenanceCategory.home,
      description: 'Regular cleaning prevents hard water stain buildup that becomes permanent. Every 2-3 months keeps them clear.',
      frequencyMonths: 3,
      recommendedMonth: 'Quarterly — spring, summer, autumn, winter.',
    ),
    MaintenancePreset(
      name: 'Bleeding Radiators',
      category: MaintenanceCategory.home,
      description: 'Air trapped in radiators makes them heat unevenly (cold at the top). Bleeding them takes 5 minutes and saves energy.',
      frequencyMonths: 12,
      recommendedMonth: 'September-October, before you turn the heating on for winter.',
    ),
    MaintenancePreset(
      name: 'Water Meter Reading',
      category: MaintenanceCategory.home,
      description: 'Submit regular readings to avoid estimated bills. Takes 2 minutes and can save you from a surprise bill.',
      frequencyMonths: 3,
      recommendedMonth: 'Submit quarterly to keep bills accurate.',
    ),
    MaintenancePreset(
      name: 'Fridge/Freezer Defrost & Clean',
      category: MaintenanceCategory.home,
      description: 'Ice buildup makes your freezer work harder and costs more to run. Clean fridge coils too for efficiency.',
      frequencyMonths: 6,
      recommendedMonth: 'Every 6 months — good excuse to throw out expired food.',
    ),

    // --- Health ---
    MaintenancePreset(
      name: 'Dentist Check-up',
      category: MaintenanceCategory.health,
      description: 'NHS recommends every 6-24 months depending on risk. Catching problems early saves pain and money.',
      frequencyMonths: 6,
      recommendedMonth: 'Book your next appointment before leaving the current one.',
    ),
    MaintenancePreset(
      name: 'Eye Test',
      category: MaintenanceCategory.health,
      description: 'Recommended every 2 years (annually if over 40 or with existing conditions). Free on the NHS if eligible.',
      frequencyMonths: 24,
      recommendedMonth: 'Every 2 years. Free for under-16s, over-60s, and those on certain benefits.',
    ),
    MaintenancePreset(
      name: 'Flu Jab',
      category: MaintenanceCategory.health,
      description: 'Free on the NHS if eligible (over 65, pregnant, certain conditions). Otherwise ~£15 at most pharmacies.',
      frequencyMonths: 12,
      recommendedMonth: 'October-November, before flu season peaks.',
    ),
    MaintenancePreset(
      name: 'NHS Prescription Prepayment Certificate',
      category: MaintenanceCategory.health,
      description: 'If you need 4+ prescriptions in 3 months or 12+ in 12 months, a PPC saves money. 12-month PPC is ~£112.',
      frequencyMonths: 12,
      recommendedMonth: 'Renew before it expires — you can set up auto-renewal.',
    ),
    MaintenancePreset(
      name: 'Health Check / Blood Test',
      category: MaintenanceCategory.health,
      description: 'NHS Health Check is free for 40-74 year olds every 5 years. Good idea to get bloods done periodically regardless.',
      frequencyMonths: 12,
      recommendedMonth: 'Annually — book through your GP.',
    ),

    // --- Tech ---
    MaintenancePreset(
      name: 'Phone Contract Renewal',
      category: MaintenanceCategory.tech,
      description: 'After your minimum term ends, you\'re likely overpaying. Switch to SIM-only or renegotiate for a much cheaper deal.',
      frequencyMonths: 12,
      recommendedMonth: 'Check your contract end date — switch immediately after.',
    ),
    MaintenancePreset(
      name: 'Broadband Contract End',
      category: MaintenanceCategory.tech,
      description: 'Out-of-contract broadband prices jump significantly. Compare and switch — or call to haggle a retention deal.',
      frequencyMonths: 18,
      recommendedMonth: 'Start comparing 4-6 weeks before your contract ends.',
    ),
    MaintenancePreset(
      name: 'Software Licence Renewals',
      category: MaintenanceCategory.tech,
      description: 'Antivirus, Office 365, Adobe, etc. Check if you still need them or if a free alternative exists.',
      frequencyMonths: 12,
      recommendedMonth: 'Review before auto-renewal charges hit your card.',
    ),
    MaintenancePreset(
      name: 'Cloud Storage Subscription',
      category: MaintenanceCategory.tech,
      description: 'iCloud, Google One, Dropbox, etc. Check your usage — you might be paying for storage you\'re not using.',
      frequencyMonths: 12,
      recommendedMonth: 'Review annually — delete old backups to potentially downgrade your plan.',
    ),
    MaintenancePreset(
      name: 'Password & Security Review',
      category: MaintenanceCategory.tech,
      description: 'Change important passwords, review 2FA settings, check for breached accounts at haveibeenpwned.com.',
      frequencyMonths: 6,
      recommendedMonth: 'Every 6 months. Use a password manager if you don\'t already.',
    ),
    MaintenancePreset(
      name: 'Computer / Phone Backup',
      category: MaintenanceCategory.tech,
      description: 'Back up photos, documents, and important files. If your device died today, what would you lose?',
      frequencyMonths: 3,
      recommendedMonth: 'Quarterly — or set up automatic backups.',
    ),

    // --- Pets ---
    MaintenancePreset(
      name: 'Vet Check-up',
      category: MaintenanceCategory.pets,
      description: 'Annual wellness exam catches health issues early. Includes weight check, teeth, and general health assessment.',
      frequencyMonths: 12,
      recommendedMonth: 'Book annually — combine with vaccination boosters.',
    ),
    MaintenancePreset(
      name: 'Pet Vaccinations / Boosters',
      category: MaintenanceCategory.pets,
      description: 'Core vaccinations need annual or triennial boosters depending on the vaccine. Check your pet\'s vaccination card.',
      frequencyMonths: 12,
      recommendedMonth: 'Your vet will send reminders — but don\'t rely on them.',
    ),
    MaintenancePreset(
      name: 'Flea / Worm Treatment',
      category: MaintenanceCategory.pets,
      description: 'Monthly flea treatment and quarterly worming for dogs/cats. Missing doses can lead to infestations.',
      frequencyMonths: 1,
      recommendedMonth: 'Monthly — set a recurring reminder on the 1st of each month.',
    ),
    MaintenancePreset(
      name: 'Pet Insurance Renewal',
      category: MaintenanceCategory.pets,
      description: 'Premiums increase with age. Review cover annually — but be careful switching as pre-existing conditions won\'t be covered.',
      frequencyMonths: 12,
      recommendedMonth: 'Compare 3-4 weeks before renewal. Be cautious about switching.',
    ),

    // --- Documents & Legal ---
    MaintenancePreset(
      name: 'Passport Renewal',
      category: MaintenanceCategory.documents,
      description: 'Expires every 10 years. Many countries require 6 months validity remaining to enter. Renewal takes 3-10 weeks.',
      frequencyMonths: 120,
      recommendedMonth: 'Renew 9 months before expiry — you won\'t lose any remaining time.',
    ),
    MaintenancePreset(
      name: 'Driving Licence Photo Renewal',
      category: MaintenanceCategory.documents,
      description: 'Photocard must be renewed every 10 years (the licence itself doesn\'t expire until 70). £14 online, £17 by post.',
      frequencyMonths: 120,
      recommendedMonth: 'DVLA sends a reminder — but set your own backup reminder.',
    ),
    MaintenancePreset(
      name: 'Tenancy Agreement Renewal',
      category: MaintenanceCategory.documents,
      description: 'Know when your fixed term ends. After that you\'re on a rolling contract — your landlord can increase rent with notice.',
      frequencyMonths: 12,
      recommendedMonth: 'Review 2-3 months before the end date. Negotiate rent early.',
    ),
    MaintenancePreset(
      name: 'Life Insurance Review',
      category: MaintenanceCategory.documents,
      description: 'Review cover after major life events: new mortgage, baby, pay rise. Make sure beneficiaries are up to date.',
      frequencyMonths: 12,
      recommendedMonth: 'Review annually or after any major life change.',
    ),
    MaintenancePreset(
      name: 'Will Review',
      category: MaintenanceCategory.documents,
      description: 'Review your will after marriages, births, property purchases, or divorces. 60% of UK adults don\'t have one.',
      frequencyMonths: 24,
      recommendedMonth: 'Review every 2 years or after major life changes.',
    ),
    MaintenancePreset(
      name: 'Credit Report Check',
      category: MaintenanceCategory.documents,
      description: 'Check for errors, fraud, and see what lenders see. Free via ClearScore, Credit Karma, or Experian.',
      frequencyMonths: 3,
      recommendedMonth: 'Quarterly — especially before applying for credit.',
    ),

    // --- Seasonal ---
    MaintenancePreset(
      name: 'Pressure Wash Driveway / Patio',
      category: MaintenanceCategory.seasonal,
      description: 'Algae and moss buildup makes surfaces slippery and damages paving. A spring clean makes a huge difference.',
      frequencyMonths: 12,
      recommendedMonth: 'March-April, as weather improves.',
    ),
    MaintenancePreset(
      name: 'Garden Prep / Lawn Care',
      category: MaintenanceCategory.seasonal,
      description: 'First mow in March, feed the lawn in April, trim hedges before nesting season (March-August). Don\'t cut hedges during nesting.',
      frequencyMonths: 12,
      recommendedMonth: 'March-April for the first big garden session.',
    ),
    MaintenancePreset(
      name: 'Winter Car Prep',
      category: MaintenanceCategory.seasonal,
      description: 'Check antifreeze levels, battery condition, tyre tread, and keep a winter kit in the boot (scraper, torch, blanket).',
      frequencyMonths: 12,
      recommendedMonth: 'October — before the first frost.',
    ),
    MaintenancePreset(
      name: 'Declutter & Charity Shop Run',
      category: MaintenanceCategory.seasonal,
      description: 'Go through wardrobes, cupboards, and storage. Donate what you don\'t use. Less clutter, more space, and a tax-free conscience.',
      frequencyMonths: 6,
      recommendedMonth: 'Spring (March) and Autumn (September) — seasonal wardrobe switch.',
    ),
    MaintenancePreset(
      name: 'Washing Machine Clean',
      category: MaintenanceCategory.seasonal,
      description: 'Run an empty hot wash with a cleaning tablet or white vinegar monthly. Prevents mould, odours, and extends machine life.',
      frequencyMonths: 1,
      recommendedMonth: 'Monthly — quick and easy maintenance.',
    ),
  ];
}

/// A preset maintenance item the user can pick during setup.
class MaintenancePreset {
  final String name;
  final MaintenanceCategory category;
  final String description;
  final int frequencyMonths;
  final String recommendedMonth;

  const MaintenancePreset({
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
