import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PawCareApp());
}

// ---------- Models ----------

class Pet {
  Pet({required this.name, required this.species, this.breed = ''});

  final String name;
  final String species;
  String breed;

  static const speciesColors = {
    'Dog': Color(0xFFF59E0B),
    'Cat': Color(0xFF8B5CF6),
    'Bird': Color(0xFF0EA5E9),
    'Other': Color(0xFF10B981),
  };

  Color get color => speciesColors[species] ?? const Color(0xFF10B981);

  Map<String, dynamic> toJson() => {'name': name, 'species': species, 'breed': breed};

  factory Pet.fromJson(Map<String, dynamic> j) =>
      Pet(name: j['name'], species: j['species'], breed: j['breed'] ?? '');
}

class CareTask {
  CareTask({
    required this.pet,
    required this.title,
    required this.category,
    required this.dueDate,
    this.done = false,
  });

  final String pet;
  String title;
  String category;
  DateTime dueDate;
  bool done;

  bool get isOverdue => !done && dueDate.isBefore(DateTime.now());

  String get dueLabel =>
      '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

  static const categoryColors = {
    'Vet': Color(0xFF2563EB),
    'Grooming': Color(0xFF8B5CF6),
    'Feeding': Color(0xFFF97316),
    'Medication': Color(0xFF10B981),
    'Other': Color(0xFF64748B),
  };

  static const categoryIcons = {
    'Vet': Icons.medical_services_outlined,
    'Grooming': Icons.content_cut,
    'Feeding': Icons.restaurant,
    'Medication': Icons.medication_outlined,
    'Other': Icons.check_circle_outline,
  };

  Color get color => categoryColors[category] ?? const Color(0xFF64748B);
  IconData get icon => categoryIcons[category] ?? Icons.check_circle_outline;

  Map<String, dynamic> toJson() => {
        'pet': pet,
        'title': title,
        'category': category,
        'dueDate': dueDate.toIso8601String(),
        'done': done,
      };

  factory CareTask.fromJson(Map<String, dynamic> j) => CareTask(
        pet: j['pet'],
        title: j['title'],
        category: j['category'],
        dueDate: DateTime.parse(j['dueDate']),
        done: j['done'] ?? false,
      );
}

const categories = ['Vet', 'Grooming', 'Feeding', 'Medication', 'Other'];

const dailyTips = [
  'Fresh water every day keeps kidneys happy.',
  'Ten minutes of play beats an hour of boredom.',
  'Brush teeth a few times a week - yes, really.',
  'A tired dog is a good dog: walk before work.',
  'Cats hunt at dawn: play before breakfast.',
  'Check paws after walks, salt and glass hide there.',
  'Rotate toys weekly so they feel new again.',
];

// ---------- App ----------

class PawCareApp extends StatelessWidget {
  const PawCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawCare',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Pet> pets = [];
  final List<CareTask> tasks = [];
  final Set<String> completedDays = {};
  int tab = 0;
  String categoryFilter = 'All';
  bool overdueOnly = false;
  bool loaded = false;
  bool onboarded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      onboarded = prefs.getBool('onboarded') ?? false;
      final petsRaw = prefs.getString('pets');
      final tasksRaw = prefs.getString('tasks');
      if (petsRaw != null) {
        pets.addAll((jsonDecode(petsRaw) as List).map((j) => Pet.fromJson(j)));
      }
      if (tasksRaw != null) {
        tasks.addAll((jsonDecode(tasksRaw) as List).map((j) => CareTask.fromJson(j)));
      }
      completedDays.addAll(prefs.getStringList('completedDays') ?? []);
      loaded = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    await prefs.setString('pets', jsonEncode(pets.map((p) => p.toJson()).toList()));
    await prefs.setString('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
    await prefs.setStringList('completedDays', completedDays.toList());
  }

  void _seedDemo() {
    pets.addAll([
      Pet(name: 'Luna', species: 'Cat', breed: 'Siamese'),
      Pet(name: 'Rocky', species: 'Dog'),
    ]);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    tasks.addAll([
      CareTask(pet: 'Luna', title: 'Vet checkup', category: 'Vet', dueDate: tomorrow),
      CareTask(
          pet: 'Rocky',
          title: 'Grooming',
          category: 'Grooming',
          dueDate: tomorrow.add(const Duration(days: 2))),
    ]);
  }

  int get streak {
    int count = 0;
    var day = DateTime.now();
    // today counts only if something was completed; otherwise start from yesterday
    if (!completedDays.contains(_dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    while (completedDays.contains(_dayKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  String get todayTip => dailyTips[DateTime.now().difference(DateTime(2026, 1, 1)).inDays % dailyTips.length];

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!onboarded) return _buildOnboarding();
    return Scaffold(
      body: tab == 0 ? _buildTasks() : _buildPets(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.pets), label: 'Pets'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => tab == 0 ? _openTaskDialog() : _openPetDialog(),
        icon: const Icon(Icons.add),
        label: Text(tab == 0 ? 'Add task' : 'Add pet'),
      ),
    );
  }

  // ---------- Onboarding ----------

  Widget _buildOnboarding() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pets, size: 72, color: Colors.white),
                const SizedBox(height: 24),
                const Text('PawCare',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text(
                  'Every vet visit, grooming and walk, in one calm place.',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => setState(() {
                    onboarded = true;
                    if (pets.isEmpty) _seedDemo();
                    _save();
                  }),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Get started', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Tasks tab ----------

  Widget _buildTasks() {
    final pending = tasks.where((t) => !t.done).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    var visible = tasks.where((t) {
      if (overdueOnly && !t.isOverdue) return false;
      if (categoryFilter != 'All' && t.category != categoryFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHero(pending, overdue)),
        SliverToBoxAdapter(child: _buildTipCard()),
        SliverToBoxAdapter(child: _buildFilters()),
        if (visible.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 250 + i * 60),
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child),
                ),
                child: _buildTaskCard(visible[i]),
              ),
              childCount: visible.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildHero(int pending, int overdue) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.pets, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text('PawCare',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          const SizedBox(height: 4),
          const Text('Care that shows up every day', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            _HeroStat(label: 'Pets', value: pets.length, icon: Icons.pets),
            _HeroStat(label: 'Pending', value: pending, icon: Icons.schedule),
            _HeroStat(label: 'Overdue', value: overdue, icon: Icons.warning_amber, warn: overdue > 0),
            _HeroStat(label: 'Streak', value: streak, icon: Icons.local_fire_department, flame: streak > 0),
          ]),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Card(
        color: const Color(0xFFFFF7ED),
        child: ListTile(
          leading: const Icon(Icons.lightbulb, color: Color(0xFFF97316)),
          title: const Text('Tip of the day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(todayTip),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(spacing: 8, runSpacing: 4, children: [
        ChoiceChip(
          label: const Text('All'),
          selected: categoryFilter == 'All',
          onSelected: (_) => setState(() => categoryFilter = 'All'),
        ),
        for (final c in categories)
          ChoiceChip(
            avatar: Icon(CareTask.categoryIcons[c], size: 16,
                color: categoryFilter == c ? Colors.white : CareTask.categoryColors[c]),
            label: Text(c),
            selected: categoryFilter == c,
            selectedColor: CareTask.categoryColors[c],
            labelStyle: TextStyle(color: categoryFilter == c ? Colors.white : null),
            onSelected: (_) => setState(() => categoryFilter = c),
          ),
        FilterChip(
          label: const Text('Overdue only'),
          selected: overdueOnly,
          selectedColor: Colors.red.shade100,
          checkmarkColor: Colors.red,
          onSelected: (v) => setState(() => overdueOnly = v),
        ),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        Icon(Icons.spa, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Nothing here. All caught up.', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Widget _buildTaskCard(CareTask t) {
    return Dismissible(
      key: ObjectKey(t),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => setState(() {
        tasks.remove(t);
        _save();
      }),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(t.icon, color: t.color),
          ),
          title: Text(t.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: t.done ? TextDecoration.lineThrough : null,
              )),
          subtitle: Text('${t.pet} - due ${t.dueLabel}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (t.isOverdue)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Chip(
                  label: Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 10)),
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                ),
              ),
            Checkbox(
              value: t.done,
              activeColor: t.color,
              onChanged: (_) => setState(() {
                t.done = !t.done;
                if (t.done) completedDays.add(_dayKey(DateTime.now()));
                _save();
              }),
            ),
          ]),
          onTap: () => _openTaskDialog(existing: t),
        ),
      ),
    );
  }

  void _openTaskDialog({CareTask? existing}) {
    if (pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a pet first (Pets tab).')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => TaskDialog(
        pets: pets,
        existing: existing,
        onSave: (pet, title, category, due) => setState(() {
          if (existing != null) {
            existing
              ..title = title
              ..category = category
              ..dueDate = due;
          } else {
            tasks.add(CareTask(pet: pet, title: title, category: category, dueDate: due));
          }
          _save();
        }),
      ),
    );
  }

  // ---------- Pets tab ----------

  Widget _buildPets() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.pets, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text('Your pets',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
              SizedBox(height: 4),
              Text('Tap a pet to edit its profile', style: TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
        if (pets.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                Icon(Icons.pets, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No pets yet. Add your first one.', style: TextStyle(color: Colors.grey)),
              ]),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildPetCard(pets[i]),
              childCount: pets.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildPetCard(Pet p) {
    final petTasks = tasks.where((t) => t.pet == p.name).length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: p.color.withOpacity(0.15),
          child: Icon(Icons.pets, color: p.color),
        ),
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${p.breed.isEmpty ? p.species : '${p.species} - ${p.breed}'} - $petTasks tasks'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => setState(() {
            tasks.removeWhere((t) => t.pet == p.name);
            pets.remove(p);
            _save();
          }),
        ),
        onTap: () => _openPetDialog(existing: p),
      ),
    );
  }

  void _openPetDialog({Pet? existing}) {
    showDialog(
      context: context,
      builder: (_) => PetDialog(
        existing: existing,
        onSave: (name, species, breed) => setState(() {
          if (existing != null) {
            final old = existing.name;
            pets[pets.indexOf(existing)] = Pet(name: name, species: species, breed: breed);
            for (var i = 0; i < tasks.length; i++) {
              final t = tasks[i];
              if (t.pet == old) {
                tasks[i] = CareTask(
                    pet: name, title: t.title, category: t.category, dueDate: t.dueDate, done: t.done);
              }
            }
          } else {
            pets.add(Pet(name: name, species: species, breed: breed));
          }
          _save();
        }),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, required this.icon, this.warn = false, this.flame = false});

  final String label;
  final int value;
  final IconData icon;
  final bool warn;
  final bool flame;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: warn ? const Color(0xFFFECACA) : (flame ? const Color(0xFFFED7AA) : Colors.white)),
          const SizedBox(height: 4),
          Text('$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
    );
  }
}

// ---------- Dialogs ----------

class TaskDialog extends StatefulWidget {
  const TaskDialog({super.key, required this.pets, this.existing, required this.onSave});

  final List<Pet> pets;
  final CareTask? existing;
  final void Function(String pet, String title, String category, DateTime due) onSave;

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late final titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final dateController =
      TextEditingController(text: widget.existing != null ? widget.existing!.dueLabel : '');
  late String selectedPet = widget.existing?.pet ?? widget.pets.first.name;
  late String selectedCategory = widget.existing?.category ?? categories.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New care task' : 'Edit task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: selectedPet,
            decoration: const InputDecoration(labelText: 'Pet'),
            items: widget.pets.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
            onChanged: (v) => setState(() => selectedPet = v!),
          ),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Task (e.g. Vet visit)'),
          ),
          DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: const InputDecoration(labelText: 'Category'),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => selectedCategory = v!),
          ),
          TextField(
            controller: dateController,
            decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD)'),
            keyboardType: TextInputType.datetime,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final title = titleController.text.trim();
            final date = DateTime.tryParse(dateController.text.trim());
            if (title.isEmpty || date == null) return;
            widget.onSave(selectedPet, title, selectedCategory, date);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class PetDialog extends StatefulWidget {
  const PetDialog({super.key, this.existing, required this.onSave});

  final Pet? existing;
  final void Function(String name, String species, String breed) onSave;

  @override
  State<PetDialog> createState() => _PetDialogState();
}

class _PetDialogState extends State<PetDialog> {
  late final nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final breedController = TextEditingController(text: widget.existing?.breed ?? '');
  late String species = widget.existing?.species ?? 'Dog';

  static const speciesOptions = ['Dog', 'Cat', 'Bird', 'Other'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New pet' : 'Edit pet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          DropdownButtonFormField<String>(
            value: species,
            decoration: const InputDecoration(labelText: 'Species'),
            items: speciesOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => species = v!),
          ),
          TextField(
            controller: breedController,
            decoration: const InputDecoration(labelText: 'Breed (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            widget.onSave(name, species, breedController.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
