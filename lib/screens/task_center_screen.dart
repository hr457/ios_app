import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/collection_api_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';

class TaskCenterScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  const TaskCenterScreen({super.key, this.onRefresh});

  @override
  State<TaskCenterScreen> createState() => _TaskCenterScreenState();
}

class _TaskCenterScreenState extends State<TaskCenterScreen> {
  List<TaskModel> myTasks = [];
  List<TaskModel> tasksSentByMe = [];
  bool isLoading = true;
  int taskToggleIndex = 0; // 0: For Me, 1: By Me
  List<String> allUsers = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadHierarchy();
    CollectionApiService.syncPendingVisits();
  }

  Future<void> _loadHierarchy() async {
    final hierarchy = await CollectionApiService.fetchHierarchyNames();
    if (mounted) {
      setState(() {
        allUsers = [
          ...hierarchy['executives'] ?? [],
          ...hierarchy['tls'] ?? [],
          ...hierarchy['acms'] ?? [],
        ];
      });
    }
  }

  Future<void> _loadTasks() async {
    // Stage 1: Fast local load if possible
    try {
      final user = await AuthService.getUserData();
      if (user != null) {
        final local = await DatabaseService().getTasks(user.name);
        if (mounted && local.isNotEmpty) {
          setState(() {
            myTasks = local.map((e) => TaskModel.fromJson(e)).where((t) => t.status == 'pending').toList();
            isLoading = false; // Show something immediately
          });
        }
      }
    } catch (_) {}

    // Stage 2: Live Sync
    final results = await Future.wait([
      CollectionApiService.fetchMyTasks(),
      CollectionApiService.fetchTasksSentByMe(),
    ]);
    
    if (mounted) {
      setState(() {
        myTasks = results[0];
        tasksSentByMe = results[1];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("TASK CENTER", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white.withValues(alpha: 0.5),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(CupertinoIcons.back, size: 22),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showCreateTaskDialog();
            },
            icon: const Icon(CupertinoIcons.add_circled, size: 22, color: primaryBlue),
          ),
          IconButton(
            onPressed: _loadTasks,
            icon: const Icon(CupertinoIcons.refresh, size: 20),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            Row(
              children: [
                _taskCategoryTab("FOR ME", 0),
                const SizedBox(width: 12),
                _taskCategoryTab("BY ME", 1),
              ],
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryBlue)))
            else
              _buildActiveList(),
          ],
        ),
      ),
    );
  }

  void _showCreateTaskDialog() {
    final caseController = TextEditingController();
    final remarkController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String? selectedToUser;
    bool isAssigning = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (allUsers.isEmpty) {
            CollectionApiService.fetchHierarchyNames().then((h) {
              if (ctx.mounted) {
                final List<String> users = [
                  ...h['executives'] ?? [],
                  ...h['tls'] ?? [],
                  ...h['acms'] ?? [],
                ].cast<String>();
                setState(() => allUsers = users);
                setDialogState(() {});
              }
            });
          }

          return AlertDialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            content: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Create New Task", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textHeading)),
                  const SizedBox(height: 24),
                  
                  if (allUsers.isEmpty)
                     const Center(child: Padding(padding: EdgeInsets.all(12), child: Text("Loading user list...", style: TextStyle(fontSize: 12, color: textMuted))))
                  else
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: "Assign To", 
                        labelStyle: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true, fillColor: bodyBg,
                      ),
                      value: selectedToUser,
                      items: allUsers.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                      onChanged: (v) => setDialogState(() => selectedToUser = v),
                    ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: caseController,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: "Case Number", 
                      labelStyle: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: bodyBg,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: remarkController,
                    maxLines: 3,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Remark/Instruction", 
                      labelStyle: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: bodyBg,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Due Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}"),
                      trailing: const Icon(CupertinoIcons.calendar, color: primaryBlue),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, 
                          initialDate: selectedDate, 
                          firstDate: DateTime.now(), 
                          lastDate: DateTime.now().add(const Duration(days: 30))
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isAssigning ? null : () async {
                        if (selectedToUser == null || caseController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
                          return;
                        }
                        
                        setDialogState(() => isAssigning = true);
                        
                        try {
                          final user = await AuthService.getUserData();
                          final task = TaskModel(
                            caseNo: caseController.text,
                            remark: remarkController.text,
                            dueDate: selectedDate,
                            fromUser: user?.name ?? 'User',
                            toUser: selectedToUser!,
                          );

                          final success = await CollectionApiService.assignTask(task);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? "Task Assigned Successfully" : "Failed to Assign Task"),
                                backgroundColor: success ? successGreen : primaryRed,
                              )
                            );
                            _loadTasks();
                            if (widget.onRefresh != null) widget.onRefresh!();
                          }
                        } finally {
                          if (mounted && context.mounted) {
                             setDialogState(() => isAssigning = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue, 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        disabledBackgroundColor: primaryBlue.withValues(alpha: 0.6)
                      ),
                      child: isAssigning 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("ASSIGN TASK", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveList() {
    final List<TaskModel> activeList = taskToggleIndex == 0 ? myTasks : tasksSentByMe;
    
    if (activeList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: premiumCardDecoration(),
        child: Column(
          children: [
            Icon(CupertinoIcons.tray_fill, size: 48, color: textMuted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text("No tasks found in this category", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: activeList.map((task) => _taskTile(task)).toList(),
    );
  }

  Widget _taskCategoryTab(String title, int index) {
    bool isSelected = taskToggleIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => taskToggleIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? primaryBlue : Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(title, style: TextStyle(color: isSelected ? Colors.white : textHeading, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _taskTile(TaskModel task) {
    bool isSentByMe = taskToggleIndex == 1;
    bool isDone = task.status.toLowerCase() == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: premiumCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              if (!isSentByMe)
                IconButton(
                  onPressed: isDone ? null : () async {
                    HapticFeedback.mediumImpact();
                    if (task.id != null) {
                      final success = await CollectionApiService.updateTaskStatus(task.id!, 'completed');
                      if (success) {
                        setState(() => myTasks.remove(task));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task Completed"), backgroundColor: successGreen));
                          if (widget.onRefresh != null) widget.onRefresh!();
                        }
                      }
                    }
                  },
                  icon: Icon(isDone ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle, color: isDone ? successGreen : primaryBlue, size: 28),
                )
              else
                 Container(
                   padding: const EdgeInsets.all(10),
                   margin: const EdgeInsets.only(right: 8),
                   decoration: BoxDecoration(color: (isDone ? successGreen : warningOrange).withValues(alpha: 0.1), shape: BoxShape.circle),
                   child: Icon(isDone ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.hourglass, color: isDone ? successGreen : warningOrange, size: 20),
                 ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CASE: ${task.caseNo}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textHeading)),
                    const SizedBox(height: 4),
                    Text(task.remark, style: const TextStyle(fontSize: 12, color: textBody, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    if (isSentByMe)
                       Text("TO: ${task.toUser}", style: const TextStyle(fontSize: 10, color: primaryBlue, fontWeight: FontWeight.w800, letterSpacing: 0.5))
                    else
                       Text("FROM: ${task.fromUser}", style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DateFormat('dd MMM').format(task.dueDate), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isDone ? successGreen : primaryRed)),
                  const SizedBox(height: 4),
                  Text(isDone ? "DONE" : "PENDING", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isDone ? successGreen : warningOrange)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
