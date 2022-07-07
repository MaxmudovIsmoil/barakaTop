@extends('layouts.app')


@section('content')

    <div class="content-wrapper">
            <div class="content-header row"></div>
            <div class="content-body">
                <!-- add btn click show modal -->
                <a href="{{ route('product.create') }}" class="btn btn-outline-primary add_btn js_add_btn">Qo'shish</a>

                <!-- users list start -->
                <section class="app-user-list">
                    <!-- list section start -->
                    <div class="card">
                        <div class="card-datatable table-responsive pt-0">
                            <table class="table table-striped" id="dataTable_product">
                                <thead class="thead-light">
                                    <tr>
                                        <th>№</th>
                                        <th>Kategoriya</th>
                                        <th>Rasmi</th>
                                        <th>Nomi</th>
                                        <th>Narxi</th>
                                        <th>Miqdori</th>
                                        <th>Status</th>
                                        <th>Chegirma</th>
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
                                            <td>{{ $p->price }}</td>
                                            <td>{{ $p->comments }}</td>
                                            <td>@if($p->active) active @else no active @endif</td>
                                            <td>{{ $p->discount }}</td>
                                            <td class="text-right">
                                                <div class="d-flex justify-content-around">
                                                    <a href="{{ route('product.edit', [$p->id]) }}" class="text-primary js_edit_btn"
                                                       title="Tahrirlash">
                                                        <i class="fas fa-pen mr-50"></i>
                                                    </a>
                                                    @if(\Helper::checkUserActions(510))
                                                        <a class="text-danger js_delete_btn" href="javascript:void(0);"
                                                           data-toggle="modal"
                                                           data-target="#deleteModal"
                                                           data-name="{{ $p->name }}"
                                                           data-url="{{ route('product.destroy', [$p->id]) }}" title="O\'chirish">
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

@endsection


@section('script')

    <script>

        $(document).ready(function() {

            $('#dataTable_product').DataTable({
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
                "order": [[ 1, 'asc' ]],
                "drawCallback": function( settings ) {
                    let api = this.api();
                    let rows = api.rows( {page:'current'} ).nodes();
                    let last = null;
                    api.column(1, { page: 'current' } ).data().each( function ( group, i ) {
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

        });
    </script>

@endsection
