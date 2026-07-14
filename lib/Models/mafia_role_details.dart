class MafiaRoleDetails {
  final String title;
  final String startupEquivalent;
  final String uxProfile;
  final String icon;
  final String color;

  const MafiaRoleDetails({
    required this.title,
    required this.startupEquivalent,
    required this.uxProfile,
    required this.icon,
    required this.color,
  });

  static const Map<String, MafiaRoleDetails> registry = {
    'don': MafiaRoleDetails(
      title: 'The Don (Boss)',
      startupEquivalent: 'Founder / CEO',
      uxProfile: 'Sets the high-level vision, coordinates overall group direction, and makes key strategic decisions. Example: A Startup Founder or CEO steering the main target.',
      icon: '👑',
      color: '#FFD700',
    ),
    'consigliere': MafiaRoleDetails(
      title: 'Consigliere',
      startupEquivalent: 'Advisor / Board Member',
      uxProfile: 'Provides high-level counsel, independent perspectives, and strategic advice outside the day-to-day operations. Example: An Advisor or Board Member giving objective guidance.',
      icon: '📜',
      color: '#C55BFF',
    ),
    'underboss': MafiaRoleDetails(
      title: 'Underboss',
      startupEquivalent: 'Co-Founder / COO / VP',
      uxProfile: 'Translates the master target into operational tasks and coordinates execution across different crews. Example: A COO or Operations Lead managing the roadmap.',
      icon: '🛡️',
      color: '#5B9AFF',
    ),
    'capo': MafiaRoleDetails(
      title: 'Caporegime (Capo)',
      startupEquivalent: 'Tech Lead / Growth Lead',
      uxProfile: 'Directly manages a designated team workspace, filtering out distractions to keep the crew focused on execution. Example: A Tech Lead or Team Manager.',
      icon: '⚔️',
      color: '#FF4500',
    ),
    'soldier': MafiaRoleDetails(
      title: 'Soldier',
      startupEquivalent: 'Core Engineer / Designer',
      uxProfile: 'Executes day-to-day tasks and collaborates directly within their workspace channels to build and deliver. Example: A Core Engineer, Designer, or Maker.',
      icon: '👤',
      color: '#FF5B5B',
    ),
    'associate': MafiaRoleDetails(
      title: 'Associate',
      startupEquivalent: 'Freelancer / Contractor',
      uxProfile: 'Handles specialized, task-specific assignments and collaborates only on tasks they are directly tagged in. Example: A Contractor, Freelancer, or Partner.',
      icon: '👤',
      color: '#808080',
    ),
  };

  static MafiaRoleDetails getForSlug(String slug) {
    return registry[slug.toLowerCase()] ?? MafiaRoleDetails(
      title: slug,
      startupEquivalent: 'Role',
      uxProfile: '',
      icon: '👤',
      color: '#808080',
    );
  }
}
