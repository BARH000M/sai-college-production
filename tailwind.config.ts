/** @type {import('tailwindcss').Config} */
const roles = ['background', 'accent', 'primary', 'secondary', 'foreground'];
const steps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];
const colors: Record<string, Record<string, string>> = {};
roles.forEach((r) => {
  colors[r] = {};
  steps.forEach((s) => {
    colors[r][s] = `oklch(var(--${r}-${s}) / <alpha-value>)`;
  });
});

export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors,
      fontFamily: {
        sans: ['var(--font-body)'],
        body: ['var(--font-body)'],
        heading: ['var(--font-heading)'],
        display: ['var(--font-heading)'],
        serif: ['var(--font-heading)'],
        label: ['var(--font-label)'],
      },
    },
  },
  plugins: [],
};