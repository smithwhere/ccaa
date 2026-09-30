(function () {
    'use strict';

    var style = document.createElement('style');
    style.id = 'ccaa-task-checkbox-style';
    style.textContent = [
        '#task-table .task-table-body .checkbox.checkbox-hide { padding-left: 20px !important; }',
        '#task-table .task-table-body .checkbox.checkbox-hide > input { display: block !important; opacity: 0 !important; width: 20px !important; height: 20px !important; top: 0 !important; left: 0 !important; cursor: pointer; }',
        '#task-table .task-table-body .checkbox.checkbox-hide > input + label { padding-left: 5px !important; }',
        '#task-table .task-table-body .checkbox.checkbox-hide > input + label:before, #task-table .task-table-body .checkbox.checkbox-hide > input + label:after { display: block !important; }'
    ].join('\\n');
    document.head.appendChild(style);

    function stopRowToggle(event) {
        event.stopPropagation();
    }

    function attachCheckboxHandlers() {
        var rows = document.querySelectorAll('#task-table .task-table-body .row[data-gid]');
        Array.prototype.forEach.call(rows, function (row) {
            var checkbox = row.querySelector('.checkbox');
            var input = checkbox && checkbox.querySelector('input[type="checkbox"]');
            var label = checkbox && checkbox.querySelector('label');

            if (input && !input.dataset.ccaaCheckboxHandler) {
                input.addEventListener('click', stopRowToggle, false);
                input.dataset.ccaaCheckboxHandler = 'true';
            }

            if (label && !label.dataset.ccaaCheckboxHandler) {
                label.addEventListener('click', stopRowToggle, false);
                label.dataset.ccaaCheckboxHandler = 'true';
            }
        });
    }

    var observer = new MutationObserver(attachCheckboxHandlers);
    observer.observe(document.documentElement, { childList: true, subtree: true });
    attachCheckboxHandlers();
}());
