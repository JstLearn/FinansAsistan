import React, { useEffect } from 'react';

// Mouse event'lerini window seviyesinde yakala ve canvas'a ilet
const FluidSimulation = () => {
  useEffect(() => {
    if (typeof window === 'undefined') return;

    let lastX = 0, lastY = 0;
    let initialized = false;

    const init = () => {
      if (initialized) return;

      const canvas = document.getElementById('fluid-canvas');
      if (!canvas) {
        return;
      }

      initialized = true;
    };

    const handleMouseMove = (e) => {
      if (!window.splatPointer || !window.pointers) return;

      const pointer = window.pointers[0];
      if (!pointer) return;

      // Orijinal kod gibi: İLK hareketlde sadece pozisyonu ayarla, splat yapma
      if (!pointer.down) {
        pointer.down = true;
        lastX = e.clientX;
        lastY = e.clientY;
        return;
      }

      // Delta hesapla (orijinal kod gibi)
      const posX = e.clientX;
      const posY = e.clientY;
      pointer.deltaX = (posX - lastX) * 0.001;
      pointer.deltaY = (lastY - posY) * 0.001;
      lastX = posX;
      lastY = posY;

      // Texcoord hesapla
      pointer.texcoordX = posX / window.innerWidth;
      pointer.texcoordY = 1.0 - posY / window.innerHeight;

      window.splatPointer(pointer);
    };

    const handleMouseDown = (e) => {
      if (window.pointers && window.pointers[0]) {
        window.pointers[0].down = true;
      }
      lastX = e.clientX;
      lastY = e.clientY;
    };

    const handleMouseUp = () => {
      if (window.pointers && window.pointers[0]) {
        window.pointers[0].down = false;
      }
    };

    // 100ms interval ile dene
    const checkInterval = setInterval(() => {
      if (window.splatPointer && window.pointers) {
        clearInterval(checkInterval);
        init();

        window.addEventListener('mousemove', handleMouseMove);
        window.addEventListener('mousedown', handleMouseDown);
        window.addEventListener('mouseup', handleMouseUp);
      }
    }, 100);

    setTimeout(() => clearInterval(checkInterval), 5000);

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mousedown', handleMouseDown);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, []);

  return null;
};

export default FluidSimulation;
