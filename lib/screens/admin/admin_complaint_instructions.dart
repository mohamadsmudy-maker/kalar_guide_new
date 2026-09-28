import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../services/image_service.dart'; // بەپێی پرۆژەکەت ناوەکە دەگۆڕدرێت

/// 📢 لیستی بەڕێوەبردنی ڕێنماییەکانی سکاڵا
class AdminComplaintInstructionsListScreen extends StatefulWidget {
  const AdminComplaintInstructionsListScreen({super.key});

  @override
  State<AdminComplaintInstructionsListScreen> createState() =>
      _AdminComplaintInstructionsListScreenState();
}

class _AdminComplaintInstructionsListScreenState
    extends State<AdminComplaintInstructionsListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _instructions = [];

  @override
  void initState() {
    super.initState();
    _fetchInstructions();
  }

  Future<void> _fetchInstructions() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('complaint_instructions')
          .select()
          .order('id', ascending: true);

      if (mounted) {
        setState(() {
          _instructions = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteInstruction(dynamic id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text("سڕینەوەی ڕێنمایی", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text("ئایا دڵنیایت لە سڕینەوەی ئەم سلایدە؟"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("نەخێر", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("سڕینەوە"),
            ),
          ],
        ),
      ),
    ) ??
        false;

    if (!confirm) return;

    try {
      await Supabase.instance.client.from('complaint_instructions').delete().eq('id', id);
      _fetchInstructions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("بە سەرکەوتوویی سڕایەوە 🗑️"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text(
            "ڕێنماییەکانی سکاڵا 📢",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          backgroundColor: const Color(0xFF1E1B2E),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _instructions.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _instructions.length,
          itemBuilder: (context, index) {
            var item = _instructions[index];
            return _buildInstructionCard(item, index);
          },
        ),
        floatingActionButton: _instructions.length >= 20
            ? null
            : FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminEditComplaintInstructionScreen()),
            ).then((_) => _fetchInstructions());
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text("زیادکردنی نوێ", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildInstructionCard(Map<String, dynamic> item, int index) {
    bool isActive = item['is_active'] ?? true;
    String imageUrl = item['image_url'] ?? '';
    String title = item['title'] ?? 'بێ ناونیشان';
    String desc = item['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isActive ? Colors.green.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🖼️ بەشی سەرەوە: وێنە + ژمارە + دۆخ
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: imageUrl.isNotEmpty
                    ? OptimizedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                )
                    : Container(
                  width: double.infinity,
                  height: 160,
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 40),
                ),
              ),
              // 🌑 Gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // 🔢 ژمارەی سلاید
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    "سلاید ${index + 1}",
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // 🟢/🔴 دۆخی چالاکی
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? "چالاک" : "ناچالاک",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 📝 بەشی خوارەوە: ناو و وەسف
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1A2E)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                // 🎯 دوگمەکانی دەستکاری و سڕینەوە
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminEditComplaintInstructionScreen(itemToEdit: item),
                            ),
                          ).then((_) => _fetchInstructions());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_rounded, color: AppColors.primary, size: 16),
                              SizedBox(width: 6),
                              Text("دەستکاری", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteInstruction(item['id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.announcement_outlined, size: 60, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            "هیچ ڕێنماییەک نییە 📭",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 6),
          Text(
            "دەتوانیت ڕێنمایی نوێ زیاد بکەیت",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminEditComplaintInstructionScreen()),
              ).then((_) => _fetchInstructions());
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text("زیادکردنی ڕێنمایی نوێ", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 2. پەڕەی زیادکردن و دەستکاری سلایدی تاکەکەسی
// ═══════════════════════════════════════════════════════════
class AdminEditComplaintInstructionScreen extends StatefulWidget {
  final Map<String, dynamic>? itemToEdit;

  const AdminEditComplaintInstructionScreen({super.key, this.itemToEdit});

  @override
  State<AdminEditComplaintInstructionScreen> createState() =>
      _AdminEditComplaintInstructionScreenState();
}

class _AdminEditComplaintInstructionScreenState
    extends State<AdminEditComplaintInstructionScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  XFile? _pickedImage;
  String? _existingImageUrl;
  bool _isActive = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      _titleCtrl.text = widget.itemToEdit!['title'] ?? '';
      _descCtrl.text = widget.itemToEdit!['description'] ?? '';
      _existingImageUrl = widget.itemToEdit!['image_url'];
      _isActive = widget.itemToEdit!['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تکایە ناونیشان پڕبکەرەوە ⚠"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      String imageUrl = _existingImageUrl ?? '';
      if (_pickedImage != null) {
        imageUrl = await ImageCompressionService.uploadImage(_pickedImage!);
      }

      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'image_url': imageUrl,
        'is_active': _isActive,
      };

      if (widget.itemToEdit == null) {
        await Supabase.instance.client.from('complaint_instructions').insert(data);
      } else {
        await Supabase.instance.client
            .from('complaint_instructions')
            .update(data)
            .eq('id', widget.itemToEdit!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("بە سەرکەوتوویی پاشەکەوت کرا ✅"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە ڕووی دا: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.itemToEdit != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            isEditing ? "دەستکاریکردنی ڕێنمایی ✏️" : "زیادکردنی ڕێنمایی نوێ 📢",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          backgroundColor: const Color(0xFF1E1B2E),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🖼️ بەشی وێنە
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text("وێنەی سلاید *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (picked != null) setState(() => _pickedImage = picked);
                      },
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                        ),
                        child: _pickedImage != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(File(_pickedImage!.path), fit: BoxFit.cover),
                        )
                            : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: OptimizedNetworkImage(imageUrl: _existingImageUrl!, fit: BoxFit.cover),
                        )
                            : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.primary),
                            SizedBox(height: 8),
                            Text("کرتە بکە بۆ هەڵبژاردنی وێنە 📸", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 📝 بەشی زانیارییەکان
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: "ناونیشانی ڕێنمایی *",
                        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        prefixIcon: const Icon(Icons.title_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: "دەق و ڕوونکردنەوەی ڕێنماییەکە",
                        alignLabelWithHint: true,
                        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 80),
                          child: Icon(Icons.description_rounded, color: AppColors.primary),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 🟢 دۆخی چالاکی
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isActive ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _isActive ? Colors.green.shade200 : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            color: _isActive ? Colors.green : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isActive ? "چالاکە" : "ناچالاکە",
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _isActive ? Colors.green.shade800 : Colors.grey.shade700),
                                ),
                                Text(
                                  _isActive ? "بەکارهێنەران دەتوانن بیبینن" : "بەکارهێنەران ناتوانن بیبینن",
                                  style: TextStyle(fontSize: 10, color: _isActive ? Colors.green.shade600 : Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isActive,
                            activeColor: Colors.green,
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 💾 دوگمەی پاشەکەوتکردن
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 22),
                  label: Text(
                    isEditing ? "نوێکردنەوە ✅" : "پاشەکەوتکردن ✅",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}