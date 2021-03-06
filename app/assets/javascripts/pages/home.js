$(function() {
  var $homeIndex = $('#home-index-container');
  var dataTable  = null;

  if ($homeIndex.length) {
    $('#transformer_file').change(handleFileSelect);

    function handleFileSelect(e) {
      var files = e.target.files;
      var file  = files[0];

      showFileDetail(file);
      if (file.type === 'text/csv') {
        showContentPreview(file);
      }
    }

    function showFileDetail(file) {
      var output = '';
          output += ' - FileName: ' + escape(file.name) + '<br />\n';
          output += ' - FileType: ' + (file.type || 'n/a') + '<br />\n';
          output += ' - FileSize: ' + file.size + ' bytes<br />\n';
          output += ' - LastModified: ' + (file.lastModifiedDate ? file.lastModifiedDate.toLocaleDateString() : 'n/a') + '<br />\n';
      $('#file-detail').html(output).removeClass('hide');
    }

    function showContentPreview(file) {
      var reader = new FileReader();
      reader.readAsText(file);

      reader.onload = function(event){
        var csv   = event.target.result;
        var data  = $.csv.toArrays(csv);
        var html  = renderTable(data);

        if (dataTable) {
          dataTable.destroy();
        }
        $('#file-content-preview').html(html).removeClass('hide');
        dataTable = initDatableFor($('#file-content-preview'));
      };

      reader.onerror = function() {
        alert('Unable to read ' + file.fileName);
      };
    }

    function renderTable(data) {
      var result = '';

      data.forEach(function(row, index) {
        if (index === 0) {
          result += '<thead>' + renderTableRow(row, true) + '</thead><tbody>';
        }
        else if (index === data.length - 1) {
          result += renderTableRow(row, false) + '</tbody>';
        }
        else {
          result += renderTableRow(row, false);
        }
      });

      return result;
    }

    function renderTableRow(row, onHeader) {
      var result = '';
      var tag = onHeader ? 'th' : 'td';

      result += '<tr>';
      row.forEach(function(item) {
        result += '<' + tag + '>' + transformTableItem(item, onHeader) + '</' + tag + '>';
      });
      result += '</tr>';

      return result;
    }

    function transformTableItem(item, onHeader) {
      return onHeader ? item.replace('-', '_') : item;
    }
  }
});
