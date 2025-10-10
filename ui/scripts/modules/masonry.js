/**
 * Masonry Layout Module
 * Provides Pinterest-style masonry grid layout for admin cards
 * Supports multiple layout strategies with graceful fallbacks
 */

(function() {
    'use strict';

    window.MasonryModule = {
        /**
         * Initialize masonry layout for a grid container
         * @param {string|HTMLElement} container - CSS selector or DOM element
         * @param {Object} options - Configuration options
         */
        init: function(container, options = {}) {
            const grid = typeof container === 'string' 
                ? document.querySelector(container) 
                : container;
            
            if (!grid) return;

            const config = {
                columnWidth: options.columnWidth || 280,
                gap: options.gap || 16,
                rowHeight: options.rowHeight || 10,
                method: options.method || 'auto', // 'auto', 'columns', 'grid'
                responsive: options.responsive !== false,
                ...options
            };

            // Detect best method
            if (config.method === 'auto') {
                config.method = this.detectBestMethod();
            }

            // Apply layout
            this.applyLayout(grid, config);

            // Re-layout on window resize (debounced)
            if (config.responsive) {
                let resizeTimer;
                window.addEventListener('resize', () => {
                    clearTimeout(resizeTimer);
                    resizeTimer = setTimeout(() => {
                        this.applyLayout(grid, config);
                    }, 250);
                });
            }
        },

        /**
         * Detect the best masonry method for current browser
         */
        detectBestMethod: function() {
            // Check for native CSS Grid Masonry support
            if (CSS.supports('grid-template-rows', 'masonry')) {
                return 'native';
            }
            
            // Check for CSS Columns support (better than manual grid)
            if (CSS.supports('column-count', '3')) {
                return 'columns';
            }
            
            // Fallback to manual grid calculation
            return 'grid';
        },

        /**
         * Apply masonry layout using selected method
         */
        applyLayout: function(grid, config) {
            switch (config.method) {
                case 'native':
                    this.applyNativeMasonry(grid);
                    break;
                case 'columns':
                    this.applyColumnsMasonry(grid, config);
                    break;
                case 'grid':
                    this.applyGridMasonry(grid, config);
                    break;
                default:
                    this.applyColumnsMasonry(grid, config);
            }
        },

        /**
         * Method 1: Native CSS Grid Masonry (Firefox, Safari TP)
         */
        applyNativeMasonry: function(grid) {
            grid.style.display = 'grid';
            grid.style.gridTemplateRows = 'masonry';
            grid.classList.remove('masonry-columns', 'masonry-grid');
        },

        /**
         * Method 2: CSS Columns Masonry (Best browser support)
         */
        applyColumnsMasonry: function(grid, config) {
            grid.classList.add('masonry-columns');
            grid.classList.remove('masonry-grid');
            
            // Calculate column count based on container width
            const containerWidth = grid.offsetWidth;
            const columnCount = Math.max(1, Math.floor(containerWidth / (config.columnWidth + config.gap)));
            
            grid.style.columnCount = columnCount;
            grid.style.columnGap = config.gap + 'px';
        },

        /**
         * Method 3: Manual Grid Masonry (JavaScript-assisted)
         * Uses grid-auto-rows with calculated grid-row: span values
         */
        applyGridMasonry: function(grid, config) {
            grid.classList.add('masonry-grid');
            grid.classList.remove('masonry-columns');
            
            grid.style.display = 'grid';
            grid.style.gridAutoRows = config.rowHeight + 'px'; // 50px base row height
            grid.style.gap = config.gap + 'px'; // 10px gap
            
            // Calculate grid-row span for each card based on actual content height
            const cards = grid.querySelectorAll('.stat-card, .result-item, .user-card, .service-card');
            
            cards.forEach(card => {
                // Reset any existing span to get natural height
                card.style.gridRow = 'auto';
                
                // Get the actual rendered height
                const cardHeight = card.offsetHeight;
                
                // Calculate how many 50px rows this card needs
                // Formula: ceil(height / rowHeight) to ensure card fits
                const rowSpan = Math.ceil(cardHeight / config.rowHeight);
                
                // Apply the calculated span
                card.style.gridRow = `span ${rowSpan}`;
                
                // Add data-size attribute for CSS styling (optional)
                if (rowSpan <= 2) {
                    card.setAttribute('data-size', 'short');
                } else if (rowSpan <= 4) {
                    card.setAttribute('data-size', 'tall');
                } else if (rowSpan <= 5) {
                    card.setAttribute('data-size', 'taller');
                } else {
                    card.setAttribute('data-size', 'tallest');
                }
            });
            
            console.log(`✓ Grid masonry: ${cards.length} cards with auto-calculated spans (${config.rowHeight}px rows)`);
        },

        /**
         * Re-layout all masonry grids on the page
         */
        relayout: function() {
            const grids = document.querySelectorAll('.stats-grid');
            grids.forEach(grid => {
                // Get stored config or use defaults
                const config = grid._masonryConfig || { method: 'auto' };
                this.applyLayout(grid, config);
            });
        },

        /**
         * Initialize all masonry grids with data-masonry attribute
         */
        autoInit: function() {
            const grids = document.querySelectorAll('[data-masonry]');
            grids.forEach(grid => {
                try {
                    const options = JSON.parse(grid.dataset.masonry || '{}');
                    this.init(grid, options);
                } catch (error) {
                    console.warn('Invalid masonry options:', error);
                    this.init(grid);
                }
            });
        },

        /**
         * Responsive column counts
         */
        getResponsiveColumns: function(containerWidth) {
            if (containerWidth < 480) return 1;
            if (containerWidth < 768) return 1;
            if (containerWidth < 1024) return 2;
            if (containerWidth < 1440) return 3;
            return 4;
        }
    };

    // Auto-initialize on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            window.MasonryModule.autoInit();
        });
    } else {
        window.MasonryModule.autoInit();
    }

    // Re-layout when admin content is loaded
    document.addEventListener('adminContentLoaded', () => {
        setTimeout(() => {
            window.MasonryModule.relayout();
        }, 100);
    });

})();
