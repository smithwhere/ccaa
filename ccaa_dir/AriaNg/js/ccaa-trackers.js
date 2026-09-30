(function () {
    'use strict';

    var trackerSources = [
        'https://cf.trackerslist.com/best.txt',
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt'
    ];

    function addRefreshButton() {
        if (window.location.hash.indexOf('#!/settings/aria2/bt') !== 0) {
            return;
        }

        var row = document.querySelector('[data-option-key="bt-tracker"]');
        if (!row || row.querySelector('.ccaa-tracker-refresh')) {
            return;
        }

        var value = row.querySelector('.setting-value');
        if (!value) {
            return;
        }

        var wrapper = document.createElement('div');
        wrapper.className = 'ccaa-tracker-refresh';
        wrapper.style.marginTop = '8px';

        var button = document.createElement('button');
        button.type = 'button';
        button.className = 'btn btn-default btn-sm';
        button.textContent = '刷新读取 BT Tracker';
        button.setAttribute('aria-label', '从两个 Tracker 列表源刷新 BT 服务器地址');
        wrapper.appendChild(button);
        value.appendChild(wrapper);

        button.addEventListener('click', function () {
            button.disabled = true;
            button.textContent = '正在读取 Tracker…';

            var requests = trackerSources.map(function (url) {
                return window.fetch(url, { cache: 'no-store' }).then(function (response) {
                    if (!response.ok) {
                        throw new Error('HTTP ' + response.status);
                    }
                    return response.text();
                }, function () {
                    return '';
                });
            });

            Promise.all(requests).then(function (sources) {
                var seen = Object.create(null);
                var trackers = [];

                sources.forEach(function (source) {
                    source.split(/\s+/).forEach(function (line) {
                        var tracker = line.replace(/\r/g, '').trim();
                        if (/^(https?|udp|ws|wss):\/\/\S+$/i.test(tracker) && !seen[tracker]) {
                            seen[tracker] = true;
                            trackers.push(tracker);
                        }
                    });
                });

                if (!trackers.length) {
                    throw new Error('两个来源均未返回有效地址');
                }

                if (!window.angular) {
                    throw new Error('AriaNg 尚未完成初始化');
                }
                var scope = window.angular.element(row).isolateScope();
                if (!scope || !scope.changeValue || !scope.optionStatus) {
                    throw new Error('未找到 BT Tracker 设置项');
                }

                return new Promise(function (resolve, reject) {
                    scope.$applyAsync(function () {
                        scope.changeValue(trackers.join(','), false);
                        var started = Date.now();
                        var timer = window.setInterval(function () {
                            var state = scope.optionStatus.getValue();
                            if (state === 'success') {
                                window.clearInterval(timer);
                                resolve(trackers.length);
                            } else if (state === 'failed' || state === 'error') {
                                window.clearInterval(timer);
                                reject(new Error('aria2 保存 BT Tracker 失败'));
                            } else if (Date.now() - started > 30000) {
                                window.clearInterval(timer);
                                reject(new Error('aria2 保存超时'));
                            }
                        }, 100);
                    });
                });
            }).then(function (count) {
                button.textContent = '已写入 ' + count + ' 条 Tracker';
            }).catch(function (error) {
                button.textContent = '刷新失败，点击重试';
                button.title = error.message || String(error);
            }).then(function () {
                button.disabled = false;
            });
        });
    }

    window.addEventListener('hashchange', addRefreshButton);
    var observer = new MutationObserver(addRefreshButton);
    observer.observe(document.getElementById('content-body') || document.body, {
        childList: true,
        subtree: true
    });
    window.setTimeout(addRefreshButton, 0);
}());
