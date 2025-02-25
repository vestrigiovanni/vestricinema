import React from 'react';
import { Link } from 'react-router-dom';

const Footer = () => {
  return (
    <footer className="bg-black py-4 mt-auto">
      <div className="container mx-auto px-4 flex justify-center items-center">
        <Link 
          to="/admin"
          className="text-gray-600 hover:text-gray-500 text-sm transition-colors"
        >
          admin
        </Link>
      </div>
    </footer>
  );
};

export default Footer;