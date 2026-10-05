(function($) {
    "use strict";

    var fixWidth = function(e, ui) {
        ui.children().each(function() {
            $(this).width($(this).width());
        });

        return ui;
    };

    var calculateOddEvenStyle = function() {
        $('#issue-todo-list-table > tbody > tr').each(function(index, tr) {
            tr = $(tr);
            tr.removeClass('odd');
            tr.removeClass('even');

            if(index % 2 == 0) {
                tr.addClass('odd');
            } else {
                tr.addClass('even');
            }

            tr.find('td.issue-todo-list-item-order').text(index + 1)
        });
    };

    var updateOrder = function(e, ui) {
        var table = $('#issue-todo-list-table');
        var itemOrder = $('#issue-todo-list-table > tbody').sortable('serialize', {
            key: 'item[]'
        });

        $.ajax({
            type: 'POST',
            url: table.data('reorder-url'),
            data: itemOrder,
            dataType: 'script',
            error: function() {
                alert(table.data('reorder-error'));
            }}
        );

        calculateOddEvenStyle();
    };

    $(document).ready(function() {
        $('#issue-todo-list-table.sortable > tbody').sortable({
            cancel: 'a, input',
            placeholder: 'issue-todo-list-placeholder',
            axis: "y",
            forcePlaceholderSize: true,
            opacity: 0.5,
            tolerance: "intersect",
            helper: fixWidth,
            update: updateOrder,
            start: function(e, ui){
                ui.placeholder.height(ui.item.height());
            }
        });
    });
})(jQuery);
