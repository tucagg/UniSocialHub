import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gtu/constants.dart';
import 'package:gtu/route/screen_export.dart';
import 'package:gtu/screens/community/views/list_community_screen.dart';
import 'package:gtu/screens/events/views/events_screen.dart';

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  final List _pages = const [
    HomeScreen(),
    CalendarScreen(),  // Add Calendar Screen
    EventsScreen(),    // Add Events Screen
    ListCommunityScreen(), // Add Community Screen
    ProfileScreen(),
  ];
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    SvgPicture svgIcon(String src, {Color? color}) {
      return SvgPicture.asset(
        src,
        height: 24,
        colorFilter: ColorFilter.mode(
            color ??
                Theme.of(context).iconTheme.color!.withOpacity(
                    Theme.of(context).brightness == Brightness.dark ? 0.3 : 1), // when you sc
            BlendMode.srcIn),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const SizedBox(),
        centerTitle: true,
        toolbarHeight: 80,
        titleSpacing: 0,
        flexibleSpace: PreferredSize(
          preferredSize: const Size.fromHeight(80.0),
          child: Center(
            child: Image.asset(
              "assets/logo/kelebek.PNG",
              height: 50,
              width: 250,
            ),
          ),
        ),
      ),
      body: PageTransitionSwitcher(
        duration: defaultDuration,
        transitionBuilder: (child, animation, secondAnimation) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondAnimation,
            child: child,
          );
        },
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: defaultPadding / 2),
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF101015),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index != _currentIndex) {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF101015),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.transparent,
          items: [
            BottomNavigationBarItem(
              icon: svgIcon("assets/icons/house-svgrepo-com.svg"),
              activeIcon:
              svgIcon("assets/icons/house-svgrepo-com.svg", color: primaryColor),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: svgIcon("assets/icons/Calendar.svg"), // Calendar icon
              activeIcon:
              svgIcon("assets/icons/Calendar.svg", color: primaryColor),
              label: "Calendar",
            ),
            BottomNavigationBarItem(
              icon: svgIcon("assets/icons/energy-svgrepo-com.svg"), // Events icon
              activeIcon:
              svgIcon("assets/icons/energy-svgrepo-com.svg", color: primaryColor),
              label: "Events",
            ),
            BottomNavigationBarItem(
              icon: svgIcon("assets/icons/group-svgrepo-com.svg"), // Events icon
              activeIcon:
              svgIcon("assets/icons/group-svgrepo-com.svg", color: primaryColor),
              label: "Community",
            ),
            BottomNavigationBarItem(
              icon: svgIcon("assets/icons/Profile.svg"),
              activeIcon:
              svgIcon("assets/icons/Profile.svg", color: primaryColor),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}