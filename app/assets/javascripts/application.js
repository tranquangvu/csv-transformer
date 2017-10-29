//= require rails-ujs
//= require jquery
//= require jquery.turbolinks
//= require bootstrap-sprockets
//= require bootstrap-datepicker
//= require parsley
//= require jquery.csv
//= require dataTables/jquery.dataTables
//= require dataTables/bootstrap/3/jquery.dataTables.bootstrap
//= require pages/home
//= require turbolinks

$(function() {
  initDatePicker();
  initParsley();
});

function initDatePicker() {
  $('.date-picker').datepicker({
    autoclose: true,
    todayHighlight: true,
    format: 'yyyy-mm-dd'
  });
}

function initParsley() {
  $('form.with-parsley').parsley({
    errorsContainer: function (el) {
      return el.$element.closest(".form-group");
    }
  });
}

function initDatableFor($target) {
  $target.DataTable({
    scrollX: true,
    pageLength: 25,
    lengthMenu: [[25, 50, 100, 200, 500], [25, 50, 100, 200, 500]],
    aaSorting: []
  });
}
