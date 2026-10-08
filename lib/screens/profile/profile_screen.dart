import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';

import '../favorites/favorites_screen.dart';
import '../videos/user_videos.dart';

/// 👤 شاشەی پرۆفایل
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ✅ Future وەک State Variable
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthSessionManager.fetchUserProfile();
  }

  // ✅ دووبارە هێنانەوەی پرۆفایل
  void _refreshProfile() {
    setState(() {
      _profileFuture = AuthSessionManager.fetchUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text(
            "پرۆفایل 👤",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshProfile,
              tooltip: 'نوێکردنەوە',
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            // ✅ پشکنینی Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final userProfile = snapshot.data;
            final user = AuthSessionManager.currentUser;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user == null
                        ? "میوانی خۆشەویست"
                        : "${userProfile?['name'] ?? 'بەکارهێنەر'}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      userProfile?['phone'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),


                  _buildMenuItem(
                    icon: Icons.favorite_rounded,
                    title: "دڵخوازەکانم",
                    color: Colors.pink,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.video_library_rounded,
                    title: "ڤیدیۆ و ڕێنماییەکان",
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserVideosScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),

                  // ✅ دوگمەی چوونەژوورەوە/دەرچوون
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: user == null
                            ? AppColors.primary
                            : Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (user == null) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthScreen(),
                            ),
                          );
                          // ✅ دوای چوونەژوورەوە، پرۆفایل نوێ بکەرەوە
                          _refreshProfile();
                        } else {
                          await AuthSessionManager.clearSession();
                          if (context.mounted) {
                            _refreshProfile();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "بە سەرکەوتوویی چوویتە دەرەوە 👋",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        user == null
                            ? "چوونەژوورەوە"
                            : "چوونەدەرەوە لە هەژمار",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}