// docs/app.js - Interactive Documentation Controller
document.addEventListener('DOMContentLoaded', () => {
  // 1. Theme Management
  const themeToggle = document.getElementById('themeToggle');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const storedTheme = localStorage.getItem('ytjsmusic_theme');
  
  if (storedTheme) {
    document.documentElement.setAttribute('data-theme', storedTheme);
    themeToggle.textContent = storedTheme === 'dark' ? '☀️ Light' : '🌙 Dark';
  } else if (prefersDark) {
    document.documentElement.setAttribute('data-theme', 'dark');
    themeToggle.textContent = '☀️ Light';
  }

  themeToggle.addEventListener('click', () => {
    const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
    const nextTheme = currentTheme === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', nextTheme);
    localStorage.setItem('ytjsmusic_theme', nextTheme);
    themeToggle.textContent = nextTheme === 'dark' ? '☀️ Light' : '🌙 Dark';
  });

  // 2. Navigation & Tab Switching
  const navLinks = document.querySelectorAll('.nav-menu .nav-item a');
  const sections = document.querySelectorAll('.doc-section');
  const mobileMenuBtn = document.getElementById('mobileMenuBtn');
  const sidebar = document.getElementById('sidebar');

  function showSection(targetId) {
    sections.forEach(sec => {
      sec.classList.remove('active');
    });

    const targetSection = document.getElementById(targetId);
    if (targetSection) {
      targetSection.classList.add('active');
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    navLinks.forEach(link => {
      const parent = link.closest('.nav-item');
      if (link.getAttribute('href') === `#${targetId}`) {
        parent.classList.add('active');
      } else {
        parent.classList.remove('active');
      }
    });

    // Close mobile menu
    if (sidebar.classList.contains('open')) {
      sidebar.classList.remove('open');
    }
  }

  navLinks.forEach(link => {
    link.addEventListener('click', (e) => {
      const href = link.getAttribute('href');
      if (href.startsWith('#')) {
        e.preventDefault();
        const targetId = href.substring(1);
        showSection(targetId);
        history.pushState(null, null, href);
      }
    });
  });

  // Check URL Hash on Load
  if (window.location.hash) {
    const initialId = window.location.hash.substring(1);
    if (document.getElementById(initialId)) {
      showSection(initialId);
    }
  }

  // 3. Mobile Sidebar Toggle
  if (mobileMenuBtn) {
    mobileMenuBtn.addEventListener('click', () => {
      sidebar.classList.toggle('open');
    });
  }

  // 4. Code Block Copy to Clipboard
  document.querySelectorAll('.btn-copy').forEach(btn => {
    btn.addEventListener('click', () => {
      const container = btn.closest('.code-container');
      const code = container.querySelector('pre code').innerText;
      navigator.clipboard.writeText(code).then(() => {
        const originalText = btn.textContent;
        btn.textContent = 'Copied!';
        btn.style.color = '#3fb950';
        setTimeout(() => {
          btn.textContent = originalText;
          btn.style.color = '';
        }, 2000);
      });
    });
  });

  // 5. Sidebar Filter / Search
  const searchInput = document.getElementById('sidebarSearch');
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      const query = e.target.value.toLowerCase().trim();
      document.querySelectorAll('.nav-menu .nav-item').forEach(item => {
        const text = item.textContent.toLowerCase();
        if (text.includes(query)) {
          item.style.display = 'block';
        } else {
          item.style.display = 'none';
        }
      });
    });
  }
});
