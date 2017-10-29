$(function() {
  var $homeIndex = $('#home-index-container');

  if ($homeIndex.length) {
    $('#transformer_file').change(handleFileSelect);

    function handleFileSelect(e) {
      var files = e.target.files;
      var file  = files[0];

      showFileDetail(file);
      showContentPreview(file);
    }

    function showFileDetail(file) {
      var output = '';
          output += '<span style="font-weight:bold;">' + escape(file.name) + '</span><br />\n';
          output += ' - FileType: ' + (file.type || 'n/a') + '<br />\n';
          output += ' - FileSize: ' + file.size + ' bytes<br />\n';
          output += ' - LastModified: ' + (file.lastModifiedDate ? file.lastModifiedDate.toLocaleDateString() : 'n/a') + '<br />\n';
      $('#file-detail').html(output);
    }

    function showContentPreview(file) {
      var reader = new FileReader();
      reader.readAsText(file);

      reader.onload = function(event){
        var csv   = event.target.result;
        var data  = $.csv.toArrays(csv);

        var html  = renderTable(data);

        $('#file-content-preview').html(html);
        initDatableFor($('#file-content-preview'));
      };

      reader.onerror = function() {
        alert('Unable to read ' + file.fileName);
      };
    }

    function renderFileDetail() {

    }

    function renderTable(data) {
      var result = '';

      data.forEach(function(row, index) {
        if (index === 0) {
          result += '<thead>' + renderTableRow(row, true) + '</thead><tbody>';
        }
        else if (index === data.length - 1) {
          result += renderTableRow(row) + '</tbody>';
        }
        else {
          result += renderTableRow(row);
        }
      });

      return result;
    }

    function renderTableRow(row, onHeader = false) {
      var result = '';
      var tag = onHeader ? 'th' : 'td';

      result += '<tr>';
      row.forEach(function(item) {
        result += '<' + tag + '>' + transformTableItem(item, onHeader) + '</' + tag + '>';
      });
      result += '</tr>';

      return result;
    }

    function transformTableItem(item, onHeader = false) {
      return onHeader ? item : item.replace('-', '_');
    }
  }
});
