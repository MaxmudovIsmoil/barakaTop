@extends('layouts.app')


@section('content')

    <div class="content-wrapper">
            <div class="content-header row"></div>
            <div class="content-body">
                <!-- add btn click show modal -->
                <a href="javascript:void(0);" data-url="{{ route('sub-category.store') }}" class="btn btn-outline-primary add_btn js_add_btn">Qo'shish</a>
                <h3 class="text-center text-info position-absolute zindex-1" style="left: 45%; top: 12px">Kategoriyalar</h3>
                <!-- users list start -->
                <section class="app-user-list">
                    <!-- list section start -->
                    <div class="card">
                        <div class="card-datatable table-responsive pt-0">
                            <table class="table table-striped" id="dataTable">
                                <thead class="thead-light">
                                    <tr>
                                        <th>№</th>
                                        <th></th>
                                        <th>Rasm</th>
                                        <th>Nomi</th>
                                        <th class="text-right">Harakatlar</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @foreach($products as $p)
                                        <tr class="js_this_tr" data-id="{{ $p->id }}">
                                            <td>{{ 1 + $loop->index }}</td>
                                            <td>{{ optional($p->partner)->name }}</td>
                                            <td>
                                                <a data-fancybox="gallery" style='background: url("{{ asset($p->image) }}")' href="{{ asset($p->image) }}">
                                                    <img src="{{ asset($p->image) }}" class="product_image" alt="photo" />
                                                </a>
                                            </td>
                                            <td>{{ $p->name }}</td>
                                            <td class="text-right">
                                                <div class="d-flex justify-content-around">
                                                    <a href="javascript:void(0);" class="text-primary js_edit_btn"
                                                       data-one_product_url="{{ route('sub-category.show', [$p->id]) }}"
                                                       data-update_url="{{ route('sub-category.update', [$p->id]) }}"
                                                       title="Tahrirlash">
                                                        <i class="fas fa-pen mr-50"></i>
                                                    </a>

                                                    @if(\Helper::checkUserActions(510))
                                                        <a class="text-danger js_delete_btn" href="javascript:void(0);"
                                                           data-toggle="modal"
                                                           data-target="#deleteModal"
                                                           data-name="{{ $p->name }}"
                                                           data-url="{{ route('sub-category.destroy', [$p->id]) }}" title="O\'chirish">
                                                            <i class="far fa-trash-alt mr-50"></i>
                                                        </a>
                                                    @else
                                                        <a class="text-secondary" href="javascript:void(0);"
                                                           data-toggle="tooltip" data-placement="top"
                                                           data-original-title="Ruxsat yo'q">
                                                            <i class="far fa-trash-alt mr-50"></i>
                                                        </a>
                                                    @endif
                                                </div>
                                            </td>
                                        </tr>
                                    @endforeach
                                </tbody>
                            </table>
                        </div>
                        <div class="m-auto pt-1">
                            {{ $products->links() }}
                        </div>
                    </div>
                    <!-- list section end -->
                </section>
                <!-- users list ends -->
            </div>
        </div>

    <!-- Edit Modal -->
    @include('sub_category.sub_category_add_modal')

@endsection


@section('script')

    <script>

        function form_clear(form) {
            form.find(".js_name").val('')
            form.find('.js_partner_id').val(0)
            form.find('.js_partner_id').trigger('change')

            form.find(".sub-category-image .image-uploader").removeClass('has-files')
            form.find(".sub-category-image .uploaded").html('')
        }

        $(document).ready(function() {

            $('#dataTable').DataTable({
                paging: false,
                pageLength: 20,
                lengthChange: false,
                searching: true,
                ordering: true,
                info: false,
                autoWidth: false,
                language: {
                    search: "",
                    searchPlaceholder: " Izlash...",
                    sLengthMenu: "Кўриш _MENU_ тадан",
                    sInfo: "Ko'rish _START_ dan _END_ gacha _TOTAL_ jami",
                    emptyTable: "Ma'lumot mavjud emas",
                },
                "columnDefs": [
                    { "visible": false, "targets": 1 }
                ],
                "order": [[ 1, 'desc' ]],
                "drawCallback": function( settings ) {
                    let api = this.api();
                    let rows = api.rows( {page:'current'} ).nodes();
                    let last = null;
                    api.column(1, { page:'current' } ).data().each( function ( group, i ) {
                        if ( last !== group ) {
                            if(group) {
                                $(rows).eq( i ).before(
                                    '<tr class="js_this_group" style="background: #19223a">' +
                                        '<td colspan="4" class="text-center"><b>'+group+'</b></td>' +
                                    '</tr>'
                                );
                            }
                            else {
                                $(rows).eq( i ).before(
                                    '<tr class="js_this_group" style="background: #19223a">' +
                                        '<td colspan="4" class="text-center"><b>Nomsiz</b></td>' +
                                    '</tr>'
                                );
                            }
                            last = group;
                        }
                    });
                }
            });


            var modal = $('#sub_category_add_modal')

            // add btn
            $(document).on('click', '.js_add_btn', function() {
                let url = $(this).data('url');
                let form = $('#js_sub_category_form_add')

                $('.sub-category-image').html('')
                $('.sub-category-image').imageUploader();

                form.attr('action', url);
                form_clear(form);
                modal.modal('show');
            });


            // edit btn
            $(document).on('click', '.js_edit_btn', function() {
                $('.sub-category-image').html('')

                let one_product_url = $(this).data('one_product_url')
                let update_url  = $(this).data('update_url')

                let form = $("#js_sub_category_form_add")
                form.attr('action', update_url)
                form.append('<input type="hidden" name="_method" value="PUT"/>')
                $.ajax({
                    type: 'GET',
                    url: one_product_url,
                    success: (response) => {

                        if(response.status) {
                            form.find('.js_name').val(response.product.name)

                            form.find('.js_partner_id').val(response.product.partner_id)
                            form.find('.js_partner_id').trigger('change')

                            $('.sub-category-image').imageUploader({ preloaded: [{id: 1, src: response.product.image}] })
                        }
                    },
                    error: (response) => {
                        console.log('error', response)
                    }
                })

                modal.modal('show')
            });




            // sub category add
            $(document).on('submit', '#js_sub_category_form_add', function(e) {
                e.preventDefault()

                let form = $('#js_sub_category_form_add')

                let url = form.attr('action');
                let method = form.attr('method');
                let formData = new FormData(this);

                $.ajax({
                    type: method,
                    url: url,
                    data: formData,
                    contentType: false,
                    processData: false,
                    success: (response) => {
                        console.log(response)
                        if(!response.status) {
                            if(typeof response.errors !== 'undefined') {
                                if (response.errors.name)
                                    form.find('.js_name').addClass('is-invalid')

                                if (response.errors.images)
                                    $('.js_images_invalid').removeClass('d-none')
                            }
                        }

                        if (response.status) {
                            location.reload()
                        }
                    },
                    error: (response) => {
                        console.log(response);
                    }
                });
            });


        });
    </script>

@endsection
