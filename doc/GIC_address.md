表格 Markdown 表格：

| 偏移地址 (Page Offset) | 页名称 | 描述/说明 |
| :--- | :--- | :--- |
| 0 | GICD | GICD main page |
| 1 | GICM | GICM message-based interrupts |
| 2 | GICT | GIC trace and debug page |
| 3 | GICP | GIC PMU page |
| 4 + 2×ITSnum | GITS | ITS address page. <br>ITSnum is the serial number of each ITS, which is from 0 to ITScount-1. |
| 5 + 2×ITSnum | GITS (translate) | ITS translation page |
| 6 + 2×ITSnum | GITS (vSGI) | ITS vSGI page |
| 7 + 2×ITSnum | Reserved | Reserved |
| 4 + 2×ITScount + 2×RDnum | GICR (LPI) | GICR LPI registers. <br>ITScount is the total number of ITS. |
| 5 + 2×ITScount + 2×RDnum | GICR (SGI) | GICR PPI + SGI registers. <br>RDnum is the serial number of each "internal Redistributor", which is from 0 to RDcount-1. |
| 6 + 2×ITScount + 2×RDnum | GICR (vLPI) | GICR vLPI registers |
| 7 + 2×ITScount + 2×RDnum | Reserved | Reserved |
| 4 + 2×ITScount + 2×RDcount | GICDA | Alias to GICD (page after last GICR page). <br>RDcount is the total number of "internal Redistributors", which equals total number of CPU cores. <br>RDcount can change if the `GICD_RDOFFRn` registers or the `gicd_pe_off` tie-off signal removes Redistributors. In this case, the GICDA page moves to the page above the last Redistributor. |

以上，然后 ITScount =1，ITSnum=0，RDcount = 6，RDnum= 0~5，基址
以上的， 2x 是不支持 virtualization 的情况， 支持 vSGI 和 vLPI 时应该是4x。