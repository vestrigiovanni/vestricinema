import React from 'react';
import { useLocation } from 'react-router-dom';

const Navbar = () => {
  const location = useLocation();
  
  // Don't render navbar on admin page
  if (location.pathname === '/admin') {
    return null;
  }

  return (
    <nav className="fixed top-0 w-full z-50 bg-gradient-to-b from-black/80 to-transparent">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-end h-16" />
      </div>
    </nav>
  );
}

export default Navbar;