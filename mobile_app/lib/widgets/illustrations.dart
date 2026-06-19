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
        <rect x="60" y="40" width="100" height="130" rx="12" fill="#1A1A25" stroke="#7C3AED" stroke-width="2"/>
        <rect x="80" y="60" width="60" height="4" rx="2" fill="#7C3AED" opacity="0.5"/>
        <rect x="80" y="75" width="40" height="4" rx="2" fill="#7C3AED" opacity="0.3"/>
        <rect x="80" y="90" width="50" height="4" rx="2" fill="#7C3AED" opacity="0.2"/>

        <rect x="145" y="92" width="78" height="98" rx="10" fill="#252530" stroke="#7C3AED" stroke-width="2"/>
        <rect x="161" y="110" width="46" height="3" rx="1.5" fill="#7C3AED" opacity="0.4"/>
        <rect x="161" y="121" width="32" height="3" rx="1.5" fill="#7C3AED" opacity="0.25"/>

        <circle cx="184" cy="155" r="18" fill="#7C3AED" fill-opacity="0.18"/>
        <path d="M179 155H189M184 150V160" stroke="#7C3AED" stroke-width="2.5" stroke-linecap="round"/>

        <rect x="40" y="154" width="88" height="68" rx="10" fill="#13131F" stroke="#7C3AED" stroke-width="2"/>
        <path d="M58 188H112" stroke="#7C3AED" stroke-width="4" stroke-linecap="round" opacity="0.55"/>
        <path d="M58 200H92" stroke="#7C3AED" stroke-width="3" stroke-linecap="round" opacity="0.3"/>
      </svg>''',
    );
  }

  // --- ONBOARDING 2: INSTANT SEND ---
  static Widget sendIllustration() {
    return SvgPicture.string(
      '''<svg width="280" height="280" viewBox="0 0 280 280" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- Phone -->
        <rect x="44" y="74" width="64" height="118" rx="14" fill="#1A1A25" stroke="#7C3AED" stroke-width="2.5"/>
        <rect x="58" y="90" width="36" height="3" rx="1.5" fill="#7C3AED" opacity="0.3"/>
        <rect x="58" y="100" width="26" height="3" rx="1.5" fill="#7C3AED" opacity="0.2"/>
        <rect x="54" y="160" width="44" height="20" rx="6" fill="#7C3AED" fill-opacity="0.2"/>
        <path d="M68 170L64 170M76 170H80" stroke="#7C3AED" stroke-width="2" stroke-linecap="round" opacity="0.7"/>

        <!-- Laptop screen -->
        <rect x="148" y="94" width="96" height="68" rx="8" fill="#13131F" stroke="white" stroke-width="2" opacity="0.7"/>
        <rect x="156" y="102" width="80" height="52" rx="4" fill="#252530"/>
        <!-- Laptop base -->
        <rect x="136" y="162" width="120" height="7" rx="3.5" fill="white" fill-opacity="0.4"/>

        <!-- Dashed connection line -->
        <path d="M110 138C124 138 132 128 148 128" stroke="#7C3AED" stroke-width="2" stroke-dasharray="6 7" opacity="0.6"/>

        <!-- Moving packet dot -->
        <circle cx="129" cy="133" r="7" fill="#7C3AED" fill-opacity="0.9"/>
        <circle cx="129" cy="133" r="4" fill="white" opacity="0.8"/>
      </svg>''',
    );
  }

  // --- ONBOARDING 3: PRIVATE & SECURE ---
  static Widget securityIllustration() {
    return SvgPicture.string(
      '''<svg width="280" height="280" viewBox="0 0 280 280" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- Background pulse rings -->
        <circle cx="140" cy="140" r="118" stroke="#7C3AED" stroke-width="1" stroke-dasharray="3 15" opacity="0.1"/>
        <circle cx="140" cy="140" r="92" stroke="#7C3AED" stroke-width="1" stroke-dasharray="3 10" opacity="0.07"/>

        <!-- Shield fill -->
        <path d="M140 40C140 40 100 50 80 60V140C80 180 140 220 140 220C140 220 200 180 200 140V60C180 50 140 40 140 40Z" fill="#7C3AED" fill-opacity="0.08"/>
        <!-- Shield border -->
        <path d="M140 40C140 40 100 50 80 60V140C80 180 140 220 140 220C140 220 200 180 200 140V60C180 50 140 40 140 40Z" stroke="#7C3AED" stroke-width="2.5" stroke-linejoin="round"/>

        <!-- Shackle (drawn before body so body overlaps the legs at entry) -->
        <path d="M122 152 L122 116 C122 96 158 96 158 116 L158 152" stroke="#7C3AED" stroke-width="9" stroke-linecap="round" fill="none"/>

        <!-- Lock body -->
        <rect x="108" y="146" width="64" height="52" rx="12" fill="#7C3AED"/>
        <!-- Top edge highlight -->
        <rect x="108" y="146" width="64" height="2.5" rx="1.5" fill="white" fill-opacity="0.18"/>
        <!-- Recessed inner panel -->
        <rect x="117" y="156" width="46" height="33" rx="8" fill="#5B21B6" opacity="0.85"/>

        <!-- Keyhole: circle -->
        <circle cx="140" cy="167" r="7.5" fill="#0F0B1E"/>
        <!-- Keyhole: slot -->
        <path d="M136.5 173 L143.5 173 L142 181 L138 181 Z" fill="#0F0B1E"/>
      </svg>''',
    );
  }
}
