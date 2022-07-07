
/**
 * Number format
 * 12340 --> 12 340
 */
function number_format(number) {
    return number.toLocaleString('ru-RU')
}

/**
 * Number format in Datatables
 */
function datatable_column_number_format(table, column)
{
    table.on( 'draw', function () {
        $('tr td:nth-child('+column+')').each(function () {
            let val = $(this).find('span').text() * 1
            let summa = number_format(val)
            $(this).find('span').text(summa)
            console.log(1111)

        })
    });
}

function product_sub_category(partner_id) {

    let url = window.location.protocol + "//" + window.location.host + "/sub-category/get-sub-category/"+partner_id;
    $(".js_sub_category option").remove()
    $(".js_sub_category").append('<option value="0">---</option>')

    $.ajax({
        url: url,
        type: "GET",
        dataType: "json",
        success: (response) => {
            console.log('res sub_cat: ', response)
            for(let i = 0; i < response.count; i++) {
                let newOption = new Option(response.sub_category[i].name, response.sub_category[i].id, true, true);
                $(".js_sub_category").append(newOption).trigger('change');
            }

        },
        error: (response) => {
            console.log('error: ', response)
        }
    })

}


function product_form_clear() {
    $('input[type="text"]').val('')
    $('textarea').val('')
}


/***
 * Save data ok
 * Show icon check
 */
function show_check_icon() {
    let icon = $(document).find('.js_check_icon')
    icon.removeClass('d-none')
    setTimeout(function () {
        icon.addClass("d-none");
    }, 2000);
}


