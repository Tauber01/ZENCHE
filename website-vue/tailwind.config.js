/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      spacing: {
        4.5: '1.125rem',
        18: '4.5rem',
      },
      colors: {
        ink: {
          DEFAULT: '#05070d',
          900: '#05070d',
          800: '#0a0e18',
          700: '#0f1422',
          600: '#161c2e',
        },
        lens: {
          DEFAULT: '#2f80ff',
          light: '#5b9bff',
          deep: '#1a5fd6',
          glow: '#7ab0ff',
        },
      },
      fontFamily: {
        sans: [
          'Inter',
          'PingFang SC',
          'HarmonyOS Sans SC',
          'Microsoft YaHei',
          'system-ui',
          '-apple-system',
          'Segoe UI',
          'sans-serif',
        ],
        mono: ['JetBrains Mono', 'SF Mono', 'Menlo', 'Consolas', 'monospace'],
      },
      backgroundImage: {
        'radial-glow': 'radial-gradient(circle at 50% 0%, rgba(47,128,255,0.18), transparent 60%)',
        'grid-faint':
          'linear-gradient(rgba(47,128,255,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(47,128,255,0.05) 1px, transparent 1px)',
      },
      backgroundSize: {
        grid: '48px 48px',
      },
      keyframes: {
        'float-slow': {
          '0%,100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-12px)' },
        },
        'pulse-glow': {
          '0%,100%': { opacity: '0.5' },
          '50%': { opacity: '1' },
        },
        'scan': {
          '0%': { transform: 'translateY(-100%)' },
          '100%': { transform: 'translateY(100%)' },
        },
      },
      animation: {
        'float-slow': 'float-slow 6s ease-in-out infinite',
        'pulse-glow': 'pulse-glow 3s ease-in-out infinite',
        'scan': 'scan 3s linear infinite',
      },
    },
  },
  plugins: [],
}
