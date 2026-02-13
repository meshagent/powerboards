(function () {
    const eventHandlerMap = new WeakMap();
    const originalAddEventListener = EventTarget.prototype.addEventListener;
    const originalRemoveEventListener = EventTarget.prototype.removeEventListener;

    EventTarget.prototype.addEventListener = function (type, listener, options) {
        originalAddEventListener.call(this, type, listener, options);

        if (!eventHandlerMap.has(this)) {
            eventHandlerMap.set(this, {});
        }

        const handlersForElement = eventHandlerMap.get(this);
        if (!handlersForElement[type]) {
            handlersForElement[type] = [];
        }
        handlersForElement[type].push(listener);
    };
    EventTarget.prototype.removeEventListener = function (type, listener, options) {
        originalRemoveEventListener.call(this, type, listener, options);

        if (eventHandlerMap.has(this)) {
            const handlersForElement = eventHandlerMap.get(this);

            if (handlersForElement[type]) {
                handlersForElement[type] = handlersForElement[type].filter(h => h !== listener);

                if (handlersForElement[type].length === 0) {
                    delete handlersForElement[type];
                }
            }
            if (Object.keys(handlersForElement).length === 0) {
                eventHandlerMap.delete(this);
            }
        }
    };
    window.removeExistingCtxHandlers = function() {
        const target = document.querySelector('flutter-view');
        const handlersForElement = eventHandlerMap.get(target) || {};
        const handle = handlersForElement['contextmenu'] || [];

        handle.forEach((listener) => {
            target.removeEventListener('contextmenu', listener);
        });
    };
})();
