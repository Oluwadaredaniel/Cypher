import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CypherIllustrations {
  static const Color accent = Color(0xFF6C63FF);

  // --- SPLASH / LOGO CORE ---
  static Widget splashCore() {
    return SvgPicture.string(
      '''<svg width="200" height="200" viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="100" cy="100" r="80" stroke="#6C63FF" stroke-width="2" stroke-dasharray="10 10" opacity="0.3"/>
        <circle cx="100" cy="100" r="60" stroke="#6C63FF" stroke-width="4" opacity="0.5"/>
        <path d="M100 40V160M40 100H160" stroke="#6C63FF" stroke-width="2" opacity="0.4"/>
        <rect x="85" y="85" width="30" height="30" rx="8" fill="#6C63FF"/>
        <path d="M100 70L130 100L100 130L70 100L100 70Z" fill="white" opacity="0.8"/>
      </svg>''',
    );
  }

  // --- ONBOARDING 1: FILES EVERYWHERE ---
  static Widget filesIllustration() {
    return SvgPicture.string(
      '''<svg width="280" height="280" viewBox="0 0 280 280" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- Floating Files -->
        <rect x="60" y="40" width="100" height="130" rx="12" fill="#1A1A1A" stroke="#6C63FF" stroke-width="2"/>
        <rect x="80" y="60" width="60" height="4" rx="2" fill="#6C63FF" opacity="0.5"/>
        <rect x="80" y="75" width="40" height="4" rx="2" fill="#6C63FF" opacity="0.3"/>
        
        <rect x="140" y="90" width="80" height="100" rx="10" fill="#262626" stroke="#6C63FF" stroke-width="2"/>
        
        <circle cx="180" cy="140" r="20" fill="#6C63FF" opacity="0.2"/>
        <path d="M175 140H185M180 135V145" stroke="#6C63FF" stroke-width="2"/>

        <rect x="40" y="150" width="90" height="70" rx="10" fill="#121212" stroke="#6C63FF" stroke-width="2"/>
        <path d="M60 185L110 185" stroke="#6C63FF" stroke-width="4" stroke-linecap="round" opacity="0.6"/>
      </svg>''',
    );
  }

  // --- ONBOARDING 2: INSTANT SEND ---
  static Widget sendIllustration() {
    return SvgPicture.string(
      '''<svg width="280" height="280" viewBox="0 0 280 280" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- Phone Outline -->
        <rect x="50" y="80" width="60" height="120" rx="12" stroke="#6C63FF" stroke-width="3"/>
        <!-- Laptop Outline -->
        <rect x="150" y="100" width="100" height="70" rx="8" stroke="white" stroke-width="3" opacity="0.8"/>
        <rect x="140" y="170" width="120" height="6" rx="3" fill="white" opacity="0.5"/>
        
        <!-- Connection Path -->
        <path d="M110 140C130 140 130 130 150 130" stroke="#6C63FF" stroke-width="2" stroke-dasharray="8 8"/>
        
        <!-- Moving Packet -->
        <circle cx="130" cy="135" r="8" fill="#6C63FF">
          <animate attributeName="cx" values="110;150" dur="1.5s" repeatCount="indefinite" />
        </circle>
      </svg>''',
    );
  }

  // --- ONBOARDING 3: PRIVATE & SECURE ---
  static Widget securityIllustration() {
    return SvgPicture.string(
      '''<svg width="280" height="280" viewBox="0 0 280 280" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- Shield -->
        <path d="M140 40C140 40 100 50 80 60V140C80 180 140 220 140 220C140 220 200 180 200 140V60C180 50 140 40 140 40Z" fill="#6C63FF" fill-opacity="0.1" stroke="#6C63FF" stroke-width="4"/>
        
        <!-- Lock -->
        <rect x="115" y="110" width="50" height="40" rx="6" fill="#6C63FF"/>
        <path d="M125 110V95C125 81.1929 136.193 70 150 70C163.807 70 175 81.1929 175 95V110" stroke="#6C63FF" stroke-width="4" stroke-linecap="round"/>
        
        <!-- WiFi Rings -->
        <circle cx="140" cy="130" r="80" stroke="#6C63FF" stroke-width="1" stroke-dasharray="5 15" opacity="0.3"/>
        <circle cx="140" cy="130" r="100" stroke="#6C63FF" stroke-width="1" stroke-dasharray="5 20" opacity="0.1"/>
      </svg>''',
    );
  }
}
