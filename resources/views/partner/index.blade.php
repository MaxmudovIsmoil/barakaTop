@extends('layouts.app')


@section('content')

    <div class="content-wrapper">
            <div class="content-header row"></div>
            <div class="content-body">
                <!-- add btn click show modal -->
                <a href="{{ route('partner.create') }}" class="btn btn-outline-primary add_btn js_add_btn">Qo'shish</a>
                <h3 class="text-center text-info position-absolute zindex-1" style="left: 45%; top: 2.4%">Do'konlar</h3>
                <!-- users list start -->
                <section class="app-user-list">
                    <!-- list section start -->
                    <div class="card">
                        <div class="card-datatable table-responsive pt-0">
                            <table class="table table-striped" id="dataTable_partner">
                                <thead class="thead-light">
                                    <tr>
                                        <th>№</th>
                                        <th></th>
                                        <th>Image</th>
                                        <th>Name</th>
                                        <th>Telefon</th>
                                        <th>Hudud</th>
                                        <th>Ish vaqti</th>
                                        <th>Izoh</th>
                                        <th>Login</th>
                                        <th class="text-right">Harakatlar</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @foreach($partners as $p)
                                        <tr class="js_this_tr" data-id="{{ $p->id }}">
                                            <td>{{ 1 + $loop->index }}</td>
                                            <td>{{ optional($p->partner_group)->name }}</td>
                                            <td>
                                                <a data-fancybox="gallery" style='background: url("{{ asset($p->image) }}")' href="{{ asset($p->image) }}">
                                                    <img src="{{ asset($p->image) }}" class="product_image" alt="photo" />
                                                </a>
                                            </td>
                                            <td>{{ $p->name }}</td>
                                            <td>{{ Helper::phoneFormat($p->phone) }}</td>
                                            <td>{{ $p->region->name }}</td>
                                            <td>{{ date("H : i", strtotime($p->open_time)) }} <br>{{ date('H : i', strtotime($p->close_time)) }}</td>
                                            <td>{{ $p->comments }}</td>
                                            <td>{{ $p->login }}</td>
                                            <td class="text-right">
                                                <div class="d-flex justify-content-around">

                                                    <div class="custom-control custom-switch">
                                                        <input type="checkbox" class="custom-control-input js_open_close_btn"
                                                               name="active"
                                                               @if($p->active == 1) checked @endif
                                                               id="active{{$p->id}}"
                                                               data-partner_id="{{ $p->id }}"
                                                               value="@if($p->active == 1) 1 @else 0 @endif">
                                                        <label class="custom-control-label" for="active{{$p->id}}"></label>
                                                    </div>

                                                    <a href="{{ route('partner.edit', [$p->id]) }}" class="text-primary js_edit_btn"
                                                       title="Tahrirlash">
                                                        <i class="fas fa-pen"></i>
                                                    </a>
                                                    @if(\Helper::checkUserActions(510))
                                                        <a class="text-danger js_delete_btn" href="javascript:void(0);"
                                                           data-toggle="modal"
                                                           data-target="#deleteModal"
                                                           data-name="{{ $p->name }}"
                                                           data-url="{{ route('partner.destroy', [$p->id]) }}" title="O\'chirish">
                                                            <i class="far fa-trash-alt"></i>
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
                            {{ $partners->links() }}
                        </div>
                    </div>
                    <!-- list section end -->
                </section>
                <!-- users list ends -->
            </div>
        </div>

    <!-- Edit Modal -->
{{--    @include('product.add_edit_product_modal')--}}

@endsection


@section('script')

    <script>

        $(document).ready(function() {

            $('#dataTable_partner').DataTable({
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
                    api.column(1, {page:'current'} ).data().each( function ( group, i ) {
                        if ( last !== group ) {
                            if(group) {
                                $(rows).eq( i ).before(
                                    '<tr class="js_this_group" style="background: #19223a">' +
                                    '<td colspan="10" class="text-center"><b>'+group+'</b></td>' +
                                    '</tr>'
                                );
                            }
                            else {
                                $(rows).eq( i ).before(
                                    '<tr class="js_this_group" style="background: #19223a">' +
                                        '<td colspan="10" class="text-center"><b>Nomsiz</b></td>' +
                                    '</tr>'
                                );
                            }
                            last = group;
                        }
                    });
                }

            });


            $(document).on('click', '.js_open_close_btn', function() {
                let val = $(this).val()
                if (val == 1)
                    val = 0;
                else
                    val = 1;

                let data = {
                    '_token' : '{{ csrf_token() }}',
                    'partner_id' : $(this).data('partner_id'),
                    'active' : val
                }

                $.ajax({
                    type: 'POST',
                    url: "{{ route('partner.open_close') }}",
                    data: data,
                    dataType: 'JSON',
                    success: (response) => {
                        if(response.status)
                            $(this).val(val)
                    },
                    error: (response) => {
                        console.log('error: ', response)
                    }
                })
            })
        });
    </script>

@endsection
